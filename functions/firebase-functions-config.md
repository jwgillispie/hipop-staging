# Firebase Functions Configuration & Monitoring Setup

## Production Configuration

### Environment Variables Setup
```bash
# Set Stripe configuration
firebase functions:config:set stripe.secret_key="sk_live_your_stripe_secret_key"
firebase functions:config:set stripe.webhook_secret="whsec_your_webhook_secret"
firebase functions:config:set stripe.publishable_key="pk_live_your_publishable_key"

# Set monitoring configuration
firebase functions:config:set monitoring.enabled=true
firebase functions:config:set monitoring.alert_webhook="https://your-alert-webhook-url"
firebase functions:config:set monitoring.alert_email="admin@yourdomain.com"

# Set security configuration
firebase functions:config:set security.max_requests_per_minute=100
firebase functions:config:set security.rate_limit_enabled=true
firebase functions:config:set security.ip_whitelist="stripe_ip_ranges"
```

### Function Memory and Timeout Configuration

For optimal performance and cost efficiency, configure functions with appropriate resources:

```typescript
// High-performance functions (payment processing, security monitoring)
export const secureStripeWebhook = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 540,
    maxInstances: 100,
    minInstances: 2, // Keep warm instances for critical payment processing
  })
  .https.onRequest(async (req, res) => {
    // Implementation
  });

// Scheduled functions (analytics, monitoring)
export const collectPerformanceMetrics = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 300,
    maxInstances: 1, // Only need one instance for scheduled tasks
  })
  .pubsub.schedule('*/5 * * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    // Implementation
  });

// Usage tracking functions (high frequency)
export const trackUsage = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    maxInstances: 50,
    minInstances: 1,
  })
  .https.onCall(async (data, context) => {
    // Implementation
  });

// Analytics functions (CPU intensive)
export const getUserUsageAnalytics = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 300,
    maxInstances: 10,
  })
  .https.onCall(async (data, context) => {
    // Implementation
  });
```

## Monitoring & Alerting Setup

### Cloud Monitoring Configuration

1. **Custom Metrics Dashboard**
   - Subscription health metrics
   - Usage tracking performance
   - Payment processing success rates
   - Security threat detection

2. **Alert Policies**
   - Function error rate > 1%
   - Payment failure rate > 5%
   - Security threats detected
   - High latency (> 5 seconds)
   - Memory usage > 80%

### Firestore Indexes for Performance

```javascript
// Required composite indexes for optimal query performance
{
  "indexes": [
    {
      "collectionGroup": "user_subscriptions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "usage_tracking",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "lastActivity", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "usage_alerts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "system_alerts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "severity", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "performance_metrics",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "security_logs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "sourceIP", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ]
}
```

## Security Best Practices

### Rate Limiting Configuration
```typescript
// Implement rate limiting for critical functions
const rateLimiter = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(userId: string, maxRequests: number = 10, windowMs: number = 60000): boolean {
  const now = Date.now();
  const userLimit = rateLimiter.get(userId);
  
  if (!userLimit || now > userLimit.resetTime) {
    rateLimiter.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }
  
  if (userLimit.count >= maxRequests) {
    return false;
  }
  
  userLimit.count++;
  return true;
}
```

### IP Whitelisting for Webhooks
```typescript
const STRIPE_IPS = [
  '54.187.174.169',
  '54.187.205.235',
  '54.187.216.72',
  // Add all Stripe webhook IPs
];

function isValidStripeIP(ip: string): boolean {
  return STRIPE_IPS.includes(ip) || ip.startsWith('192.168.') || ip === '127.0.0.1';
}
```

## Performance Optimization

### Batch Operations
```typescript
// Use batch operations for better performance
async function batchUpdateUsage(updates: Array<{ userId: string; data: any }>) {
  const batch = db.batch();
  
  updates.forEach(update => {
    const ref = db.collection('usage_tracking').doc(update.userId);
    batch.set(ref, update.data, { merge: true });
  });
  
  await batch.commit();
}
```

### Caching Strategy
```typescript
// Implement memory caching for frequently accessed data
const cache = new Map<string, { data: any; expiry: number }>();

function getCached(key: string): any | null {
  const cached = cache.get(key);
  if (cached && Date.now() < cached.expiry) {
    return cached.data;
  }
  cache.delete(key);
  return null;
}

function setCache(key: string, data: any, ttlMs: number = 300000) {
  cache.set(key, { data, expiry: Date.now() + ttlMs });
}
```

## Deployment Commands

### Development
```bash
# Install dependencies
npm install

# Build and test locally
npm run build
firebase emulators:start --only functions,firestore

# Deploy to staging
firebase use staging
firebase deploy --only functions

# View logs
firebase functions:log --only trackUsage,enforceUsageLimit
```

### Production
```bash
# Deploy with full monitoring
firebase use production
firebase deploy --only functions

# Set up monitoring alerts
gcloud alpha monitoring policies create --policy-from-file=monitoring-policy.yaml

# Monitor deployment
firebase functions:log --follow
```

## Debugging & Testing Commands

### Local Testing
```bash
# Test individual functions
firebase functions:shell

# In the shell:
trackUsage({userId: 'test', featureName: 'global_products', amount: 1})
enforceUsageLimit({userId: 'test', featureName: 'global_products'})
getUserUsageAnalytics({userId: 'test', months: 3})
```

### Production Debugging
```bash
# Enable debug logging
firebase functions:config:set debug.enabled=true
firebase deploy --only functions

# Stream logs with filters
firebase functions:log --only trackUsage --filter="DEBUG"

# Monitor specific user
firebase functions:log --filter="userId: specific-user-id"

# Security monitoring
firebase functions:log --only monitorPaymentSecurity --filter="severity: high"
```

## Monitoring Queries

### Cloud Logging Queries
```
# Payment processing errors
resource.type="cloud_function"
resource.labels.function_name="secureStripeWebhook"
severity>=ERROR

# High usage alerts
resource.type="cloud_function" 
jsonPayload.message="Usage alert created"
jsonPayload.percentage>=90

# Security threats
resource.type="cloud_function"
jsonPayload.message="High security risk detected"

# Performance issues
resource.type="cloud_function"
jsonPayload.totalTime>=5000
```

### Metrics for Dashboards
```
# Function invocation rate
cloudfunctions.googleapis.com/function/execution_count

# Function duration
cloudfunctions.googleapis.com/function/execution_times

# Error rate
cloudfunctions.googleapis.com/function/user_memory_bytes

# Memory usage
cloudfunctions.googleapis.com/function/user_memory_bytes
```

## Data Retention Policies

### Automated Cleanup
```typescript
// Clean up old logs and metrics (run monthly)
export const cleanupOldData = functions.pubsub
  .schedule('0 2 1 * *')
  .onRun(async (context) => {
    const threeMonthsAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    
    // Clean up old performance metrics
    const oldMetrics = await db
      .collection('performance_metrics')
      .where('timestamp', '<', threeMonthsAgo)
      .get();
    
    const batch = db.batch();
    oldMetrics.docs.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
  });
```

This configuration ensures production-ready scalability, monitoring, and security for the HiPop premium subscription system.