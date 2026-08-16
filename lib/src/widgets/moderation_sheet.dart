import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../services/moderation_service.dart';
import '../utils/snackbar_helper.dart';

// ─── Entry point: show the options sheet ─────────────────────────────────────

/// Shows a bottom sheet with Block / Mute / Report options.
///
/// [targetUserId]  — the user being actioned (profile owner / post author)
/// [postId]        — pass when called from a post; null for profile-level actions
/// [targetName]    — display name shown in dialogs
/// [onActionDone]  — called after any successful action so caller can refresh
Future<void> showModerationSheet(
  BuildContext context, {
  required String targetUserId,
  String? postId,
  required String targetName,
  VoidCallback? onActionDone,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ModerationSheet(
      targetUserId: targetUserId,
      postId: postId,
      targetName: targetName,
      onActionDone: onActionDone,
    ),
  );
}

// ─── Sheet widget ─────────────────────────────────────────────────────────────

class _ModerationSheet extends StatefulWidget {
  final String targetUserId;
  final String? postId;
  final String targetName;
  final VoidCallback? onActionDone;

  const _ModerationSheet({
    required this.targetUserId,
    this.postId,
    required this.targetName,
    this.onActionDone,
  });

  @override
  State<_ModerationSheet> createState() => _ModerationSheetState();
}

class _ModerationSheetState extends State<_ModerationSheet> {
  bool _loading = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
      widget.onActionDone?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, 'Action failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFE4E4E7), borderRadius: BorderRadius.circular(2)),
            ),

            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: Color(0xFFFF6B2C)))
            else ...[
              // Report post (only available when postId is provided)
              if (widget.postId != null) ...[
                _SheetTile(
                  icon: Icons.flag_outlined,
                  label: 'Report post',
                  color: const Color(0xFFEF4444),
                  onTap: () => _showReportDialog(context),
                ),
                const Divider(height: 1),
              ],

              // Mute
              _SheetTile(
                icon: Icons.volume_off_outlined,
                label: 'Mute ${widget.targetName}',
                subtitle: 'Their posts won\'t appear in your feed',
                onTap: () => _run(() => ModerationService.muteUser(widget.targetUserId)),
              ),
              const Divider(height: 1),

              // Block
              _SheetTile(
                icon: Icons.block_outlined,
                label: 'Block ${widget.targetName}',
                subtitle: 'They won\'t be able to see your profile or contact you',
                color: const Color(0xFFEF4444),
                onTap: () => _showBlockConfirm(context),
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTypography.dmSans(fontSize: 15, color: const Color(0xFF6B7280))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBlockConfirm(BuildContext context) {
    Navigator.pop(context); // close sheet first
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block ${widget.targetName}?', style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          '${widget.targetName} won\'t be able to see your profile, rides, or contact you. You can unblock them later from settings.',
          style: AppTypography.dmSans(fontSize: 14, color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTypography.dmSans())),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ModerationService.blockUser(widget.targetUserId);
                widget.onActionDone?.call();
                if (context.mounted) showSuccess(context, '${widget.targetName} has been blocked.');
              } catch (_) {
                if (context.mounted) showError(context, 'Failed to block. Please try again.');
              }
            },
            child: Text('Block', style: AppTypography.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    Navigator.pop(context); // close sheet first
    showDialog(
      context: context,
      builder: (ctx) => _ReportDialog(
        postId: widget.postId!,
        targetName: widget.targetName,
        onDone: widget.onActionDone,
      ),
    );
  }
}

// ─── Report reason dialog ─────────────────────────────────────────────────────

class _ReportDialog extends StatefulWidget {
  final String postId;
  final String targetName;
  final VoidCallback? onDone;

  const _ReportDialog({ required this.postId, required this.targetName, this.onDone });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _loading = false;

  static const _reasons = [
    ('nudity',     '🔞 Nudity or sexual content'),
    ('harassment', '😠 Harassment or bullying'),
    ('spam',       '📢 Spam or misleading'),
    ('violence',   '⚠️ Violence or dangerous content'),
    ('fake',       '🤥 False information'),
    ('other',      '❓ Other'),
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _loading = true);
    try {
      await ModerationService.reportPost(
        widget.postId,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      );
      widget.onDone?.call();
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Report submitted. The post has been hidden pending review.');
      }
    } catch (e) {
      if (mounted) showError(context, 'Failed to submit report.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report this post', style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 4),
            Text('Why are you reporting this?', style: AppTypography.dmSans(fontSize: 13, color: const Color(0xFF6B7280))),
            const SizedBox(height: 14),
            ..._reasons.map((r) => GestureDetector(
              onTap: () => setState(() => _selectedReason = r.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _selectedReason == r.$1 ? const Color(0xFFFFF0EB) : const Color(0xFFF5F5F7),
                  border: Border.all(
                    color: _selectedReason == r.$1 ? const Color(0xFFFF6B2C) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Text(r.$2, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (_selectedReason == r.$1)
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFFFF6B2C)),
                  ],
                ),
              ),
            )),
            if (_selectedReason != null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 2,
                style: AppTypography.dmSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)…',
                  hintStyle: AppTypography.dmSans(fontSize: 13, color: const Color(0xFFA1A1AA)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: AppTypography.dmSans(color: const Color(0xFF6B7280))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedReason == null || _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B2C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Submit report', style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile helper ──────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color = const Color(0xFF1A1A1A),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: AppTypography.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
      subtitle: subtitle != null
        ? Text(subtitle!, style: AppTypography.dmSans(fontSize: 12, color: const Color(0xFF9CA3AF)))
        : null,
    );
  }
}
