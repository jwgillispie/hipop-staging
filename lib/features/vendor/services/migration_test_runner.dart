import 'package:flutter/foundation.dart';
import 'vendor_market_migration_service.dart';

/// Test runner for the vendor-market migration system
class MigrationTestRunner {
  
  /// Run a comprehensive test of the migration system
  static Future<void> runMigrationTests() async {
    debugPrint('🧪 Starting migration system tests...');
    
    try {
      // Test 1: Dry run analysis
      debugPrint('\n📊 Test 1: Running dry run analysis...');
      final dryRunResult = await VendorMarketMigrationService.executeMigration(
        dryRun: true,
        batchSize: 100,
      );
      
      if (dryRunResult.success) {
        debugPrint('✅ Dry run completed successfully');
        debugPrint('   - Would process: ${dryRunResult.postsProcessed} posts');
        debugPrint('   - Would update: ${dryRunResult.postsUpdated} posts');
        debugPrint('   - Would create: ${dryRunResult.trackingCreated} tracking docs');
      } else {
        debugPrint('❌ Dry run failed: ${dryRunResult.error}');
        return;
      }
      
      // Test 2: Ask for confirmation before live migration
      debugPrint('\n⚠️  Ready to run LIVE migration based on dry run results.');
      debugPrint('   This will make permanent changes to your database.');
      debugPrint('   Continue? (This is a test - migration will NOT run automatically)');
      
      // In a real scenario, you would prompt for user confirmation here
      final shouldRunLiveMigration = false; // Set to true to run live migration
      
      if (shouldRunLiveMigration) {
        debugPrint('\n🚀 Test 2: Running live migration...');
        final liveResult = await VendorMarketMigrationService.executeMigration(
          dryRun: false,
          batchSize: 100,
        );
        
        if (liveResult.success) {
          debugPrint('✅ Live migration completed successfully');
          
          // Test 3: Validate migration results
          debugPrint('\n🔍 Test 3: Validating migration results...');
          final validation = await VendorMarketMigrationService.validateMigration();
          
          if (validation.success) {
            debugPrint('✅ Migration validation passed');
          } else {
            debugPrint('❌ Migration validation failed');
            debugPrint('Issues found:');
            for (final issue in validation.issues) {
              debugPrint('   - $issue');
            }
          }
          
        } else {
          debugPrint('❌ Live migration failed: ${liveResult.error}');
        }
      } else {
        debugPrint('⏭️  Skipping live migration (test mode)');
      }
      
      debugPrint('\n🎉 Migration tests completed!');
      
    } catch (e) {
      debugPrint('❌ Migration test failed: $e');
    }
  }
  
  /// Test the rollback functionality (USE WITH EXTREME CAUTION)
  static Future<void> testRollback() async {
    debugPrint('🚨 WARNING: Testing rollback functionality');
    debugPrint('   This will REMOVE all migration changes from the database!');
    debugPrint('   Only use this if you need to revert the migration.');
    
    // In a real scenario, require explicit confirmation
    final shouldRollback = false; // Set to true only if you really want to rollback
    
    if (shouldRollback) {
      try {
        await VendorMarketMigrationService.rollbackMigration();
        debugPrint('✅ Rollback completed');
      } catch (e) {
        debugPrint('❌ Rollback failed: $e');
      }
    } else {
      debugPrint('⏭️  Rollback test skipped (safety mode)');
    }
  }
  
  /// Quick validation check without running migration
  static Future<void> quickValidationCheck() async {
    debugPrint('🔍 Running quick validation check...');
    
    try {
      final validation = await VendorMarketMigrationService.validateMigration();
      
      debugPrint('📊 Current system state:');
      debugPrint('   - Valid posts: ${validation.validPosts}');
      debugPrint('   - Invalid posts: ${validation.invalidPosts}');
      debugPrint('   - Tracking docs: ${validation.trackingDocs}');
      debugPrint('   - Issues: ${validation.issues.length}');
      
      if (validation.success) {
        debugPrint('✅ System appears to be properly migrated');
      } else {
        debugPrint('⚠️  Issues found:');
        for (final issue in validation.issues) {
          debugPrint('   - $issue');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Validation check failed: $e');
    }
  }
  
  /// Display migration instructions
  static void displayMigrationInstructions() {
    debugPrint('📋 VENDOR-MARKET SYSTEM MIGRATION INSTRUCTIONS');
    debugPrint('');
    debugPrint('This migration transforms the vendor-market interaction system from:');
    debugPrint('  OLD: Vendor requests permission → Market approves → Vendor creates post');
    debugPrint('  NEW: Vendor creates post (selects market) → Market reviews post → Approve/Deny');
    debugPrint('');
    debugPrint('🔧 BEFORE RUNNING:');
    debugPrint('1. Backup your Firestore database');
    debugPrint('2. Deploy the new Firestore indexes from firestore.indexes.json');
    debugPrint('3. Test on a staging environment first');
    debugPrint('');
    debugPrint('🚀 TO RUN MIGRATION:');
    debugPrint('1. Call: MigrationTestRunner.runMigrationTests()');
    debugPrint('2. Review dry run results carefully');
    debugPrint('3. Set shouldRunLiveMigration = true in the test runner');
    debugPrint('4. Monitor the migration progress');
    debugPrint('5. Validate results after completion');
    debugPrint('');
    debugPrint('🚨 EMERGENCY ROLLBACK:');
    debugPrint('- Call: MigrationTestRunner.testRollback() with shouldRollback = true');
    debugPrint('- This will remove ALL migration changes');
    debugPrint('- Use only if migration fails and you need to revert');
    debugPrint('');
    debugPrint('📞 SUPPORT:');
    debugPrint('- Check migration logs for detailed progress');
    debugPrint('- Use quickValidationCheck() to verify system state');
    debugPrint('- Report issues with specific error messages');
    debugPrint('');
  }
}

/// Example usage of the migration system
class MigrationExample {
  
  /// Example of how to run the migration in production
  static Future<void> productionMigrationExample() async {
    // Step 1: Display instructions
    MigrationTestRunner.displayMigrationInstructions();
    
    // Step 2: Validate current state
    await MigrationTestRunner.quickValidationCheck();
    
    // Step 3: Run tests (with dry run)
    await MigrationTestRunner.runMigrationTests();
    
    debugPrint('📝 Migration process completed. Review results carefully.');
  }
}