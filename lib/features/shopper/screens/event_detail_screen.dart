import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/models/event.dart';
import '../../shared/blocs/event_detail/event_detail_bloc.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../shared/widgets/common/error_widget.dart' as common_error;
import '../../shared/widgets/common/cached_image_widget.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;
  final Event? event; // Optional: if event data is already available

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.event,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EventDetailBloc()..add(LoadEventDetail(eventId)),
      child: EventDetailView(initialEvent: event),
    );
  }
}

class EventDetailView extends StatelessWidget {
  final Event? initialEvent;

  const EventDetailView({super.key, this.initialEvent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<EventDetailBloc, EventDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case EventDetailStatus.initial:
            case EventDetailStatus.loading:
              if (initialEvent != null) {
                // Show initial event data while loading fresh data
                return _buildEventContent(context, initialEvent!, state.isFavorite, true);
              }
              return const Center(child: LoadingWidget());

            case EventDetailStatus.loaded:
              return _buildEventContent(context, state.event!, state.isFavorite, false);

            case EventDetailStatus.error:
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Event Details'),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                body: Center(
                  child: common_error.ErrorDisplayWidget(
                    title: 'Error',
                    message: state.errorMessage ?? 'Failed to load event details',
                    onRetry: () => context.read<EventDetailBloc>().add(const RefreshEventDetail()),
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildEventContent(BuildContext context, Event event, bool isFavorite, bool isLoading) {
    return CustomScrollView(
      slivers: [
        // Hero Image with App Bar
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            // Favorite Button
            Semantics(
              label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              child: IconButton(
                onPressed: isLoading ? null : () {
                  context.read<EventDetailBloc>().add(const ToggleEventFavorite());
                },
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey[600],
                ),
              ),
            ),
            // Share Button
            Semantics(
              label: 'Share event',
              child: IconButton(
                onPressed: () => _shareEvent(context, event),
                icon: const Icon(Icons.share),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Hero Image
                if (event.imageUrl != null)
                  CachedImageWidget(
                    imageUrl: event.imageUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.event,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Event Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Title
                Semantics(
                  header: true,
                  child: Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Event Status Badge
                _buildStatusBadge(context, event),
                const SizedBox(height: 24),

                // Date and Time Card
                _buildInfoCard(
                  context,
                  icon: Icons.schedule,
                  title: 'Date & Time',
                  content: _formatEventDateTime(event),
                  semanticLabel: 'Event date and time: ${_formatEventDateTime(event)}',
                ),
                const SizedBox(height: 16),

                // Location Card
                _buildInfoCard(
                  context,
                  icon: Icons.location_on,
                  title: 'Location',
                  content: '${event.location}\n${event.address}\n${event.city}, ${event.state}',
                  semanticLabel: 'Event location: ${event.location}, ${event.address}, ${event.city}, ${event.state}',
                  onTap: () => _openMaps(context, event),
                ),
                const SizedBox(height: 16),

                // Organizer Card (if available)
                if (event.organizerName != null)
                  _buildInfoCard(
                    context,
                    icon: Icons.person,
                    title: 'Organizer',
                    content: event.organizerName!,
                    semanticLabel: 'Event organizer: ${event.organizerName}',
                  ),
                if (event.organizerName != null) const SizedBox(height: 16),

                // Description Card
                if (event.description.isNotEmpty)
                  _buildDescriptionCard(context, event.description),
                if (event.description.isNotEmpty) const SizedBox(height: 16),

                // Tags
                if (event.tags.isNotEmpty)
                  _buildTagsSection(context, event.tags),
                if (event.tags.isNotEmpty) const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(context, event),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, Event event) {
    String statusText;
    Color backgroundColor;
    Color textColor;

    if (event.isCurrentlyActive) {
      statusText = 'Happening Now';
      backgroundColor = Colors.green;
      textColor = Colors.white;
    } else if (event.isUpcoming) {
      statusText = 'Upcoming';
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    } else {
      statusText = 'Ended';
      backgroundColor = Colors.grey;
      textColor = Colors.white;
    }

    return Semantics(
      label: 'Event status: $statusText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    String? semanticLabel,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: semanticLabel ?? '$title: $content',
      button: onTap != null,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String description) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'About This Event',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Event description: $description',
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Event tags: ${tags.join(', ')}',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: Colors.purple[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Event event) {
    return Column(
      children: [
        // Get Directions Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openMaps(context, event),
            icon: const Icon(Icons.directions),
            label: const Text('Get Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Secondary Actions Row
        Row(
          children: [
            // Add to Calendar Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addToCalendar(context, event),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Add to Calendar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Share Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareEvent(context, event),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatEventDateTime(Event event) {
    final startDate = event.startDateTime;
    final endDate = event.endDateTime;
    
    // Simple date/time formatting without intl package
    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);
    final startTimeStr = _formatTime(startDate);
    final endTimeStr = _formatTime(endDate);
    
    if (startDate.day == endDate.day &&
        startDate.month == endDate.month &&
        startDate.year == endDate.year) {
      // Same day event
      return '$startDateStr\n$startTimeStr - $endTimeStr';
    } else {
      // Multi-day event
      return '$startDateStr $startTimeStr\nto\n$endDateStr $endTimeStr';
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }

  void _openMaps(BuildContext context, Event event) async {
    final url = 'https://maps.google.com/?q=${event.latitude},${event.longitude}';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToCalendar(BuildContext context, Event event) {
    // For now, show a snackbar. In a real app, you'd integrate with calendar APIs
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar integration coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _shareEvent(BuildContext context, Event event) async {
    try {
      final content = _buildEventShareContent(event);
      
      final result = await Share.share(
        content,
        subject: 'Check out this event on HiPop!',
      );

      // Show success message if sharing was successful
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Event shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to share event: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _buildEventShareContent(Event event) {
    final buffer = StringBuffer();
    
    buffer.writeln('Event Alert!');
    buffer.writeln();
    buffer.writeln('${event.name}');
    if (event.description.isNotEmpty) {
      buffer.writeln(event.description);
    }
    buffer.writeln();
    buffer.writeln('Location: ${event.location}');
    buffer.writeln('When: ${_formatDateTime(event.startDateTime, event.endDateTime)}');
    buffer.writeln();
    buffer.writeln('Discovered on HiPop - Discover local pop-ups and markets');
    buffer.writeln('Download: https://hipopapp.com');
    buffer.writeln();
    buffer.writeln('#Event #LocalEvents #${event.location.replaceAll(' ', '')} #HiPop');
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    String formatDate(DateTime date) {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    
    String formatTime(DateTime time) {
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    }
    
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      // Same day
      return '${formatDate(start)} • ${formatTime(start)} - ${formatTime(end)}';
    } else {
      // Multi-day
      return '${formatDate(start)} ${formatTime(start)} - ${formatDate(end)} ${formatTime(end)}';
    }
  }
}