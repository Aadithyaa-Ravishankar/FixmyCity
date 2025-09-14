import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SeverityRatingDialog extends StatefulWidget {
  final bool isLike;
  final Function(int severity) onRatingSubmitted;

  const SeverityRatingDialog({
    super.key,
    required this.isLike,
    required this.onRatingSubmitted,
  });

  @override
  State<SeverityRatingDialog> createState() => _SeverityRatingDialogState();
}

class _SeverityRatingDialogState extends State<SeverityRatingDialog> {
  int _selectedSeverity = 3; // Default to medium severity

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.largeRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isLike 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isLike ? Icons.thumb_up : Icons.thumb_down,
                    color: widget.isLike ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate Severity',
                        style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        widget.isLike 
                            ? 'How severe is this issue?'
                            : 'Rate the severity of this report',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Severity Rating Scale
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  Text(
                    'Severity Level: $_selectedSeverity',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rating buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final severity = index + 1;
                      final isSelected = _selectedSeverity == severity;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSeverity = severity;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? _getSeverityColor(severity)
                                : AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: _getSeverityColor(severity),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: _getSeverityColor(severity).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              severity.toString(),
                              style: TextStyle(
                                color: isSelected 
                                    ? Colors.white 
                                    : _getSeverityColor(severity),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  
                  // Severity labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Low',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Medium',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'High',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.mediumRadius,
                        side: BorderSide(color: AppTheme.borderLight),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onRatingSubmitted(_selectedSeverity);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.mediumRadius,
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Submit',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
