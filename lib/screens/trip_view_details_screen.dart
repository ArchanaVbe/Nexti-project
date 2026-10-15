import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripViewDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback? onTripUpdated;

  const TripViewDetailsScreen({
    super.key,
    required this.trip,
    this.onTripUpdated,
  });

  @override
  State<TripViewDetailsScreen> createState() => _TripViewDetailsScreenState();
}

class _TripViewDetailsScreenState extends State<TripViewDetailsScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _trip;
  late String _tripCode;
  TabController? _planTabController;
  bool _isRemovingMember = false;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
    _tripCode = (_trip['tripCode'] ?? _trip['id'] ?? '').toString();
    _planTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _planTabController?.dispose();
    super.dispose();
  }

  int _calculateDays() {
    final start = _trip['startDate']?.toString().trim();
    final end = _trip['endDate']?.toString().trim();
    if (start != null && end != null) {
      try {
        final sParts = start.split('/');
        final eParts = end.split('/');
        if (sParts.length == 3 && eParts.length == 3) {
          final sDate = DateTime(int.parse(sParts[2]), int.parse(sParts[1]), int.parse(sParts[0]));
          final eDate = DateTime(int.parse(eParts[2]), int.parse(eParts[1]), int.parse(eParts[0]));
          final diff = eDate.difference(sDate).inDays + 1;
          if (diff > 0) return diff;
        }
      } catch (_) {}
    }

    final schedule = _getScheduleList(_trip['itineraryPlan'] ?? _trip['schedule']);
    if (schedule.isNotEmpty) {
      return schedule.length;
    }
    return 1;
  }

  List<Map<String, dynamic>> _getScheduleList(dynamic planData) {
    if (planData == null) return [];
    if (planData is List) {
      return planData.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (planData is Map) {
      final schedule = planData['schedule'] ?? planData['days'];
      if (schedule is List) {
        return schedule.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<void> _removeMember({
    required String memberUid,
    required String memberEmail,
    required Map<String, dynamic> memberMap,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove "$memberEmail" from this trip plan?\n\n'
          'Once removed, this trip plan will no longer be visible or accessible to them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRemovingMember = true);

    try {
      if (_tripCode.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('trips').doc(_tripCode);
        
        // Remove from members and add to blacklist
        await docRef.set({
          'approvedMembers': FieldValue.arrayRemove([memberMap]),
          'members': FieldValue.arrayRemove([memberMap]),
          'memberUids': FieldValue.arrayRemove([memberUid]),
          'removedUids': FieldValue.arrayUnion([memberUid]),
          'removedEmails': FieldValue.arrayUnion([memberEmail.trim().toLowerCase()]),
        }, SetOptions(merge: true));

        // Update local member count
        final currentMembers = (_trip['approvedMembers'] as List?) ?? (_trip['members'] as List?) ?? [];
        currentMembers.removeWhere((m) => (m is Map && (m['uid'] == memberUid || m['email'] == memberEmail)));
        _trip['approvedMembers'] = currentMembers;
        _trip['members'] = currentMembers;
        _trip['memberCount'] = currentMembers.length;

        // Persist update locally
        final prefs = await SharedPreferences.getInstance();
        final user = FirebaseAuth.instance.currentUser;
        final userEmail = user?.email?.trim().toLowerCase() ?? '';
        final key = userEmail.isNotEmpty ? 'saved_trips_$userEmail' : 'saved_trips';
        final savedList = prefs.getStringList(key) ?? [];
        for (int i = 0; i < savedList.length; i++) {
          try {
            final decoded = jsonDecode(savedList[i]);
            if (decoded['tripCode'] == _tripCode || decoded['id'] == _tripCode) {
              savedList[i] = jsonEncode(_trip);
              break;
            }
          } catch (_) {}
        }
        await prefs.setStringList(key, savedList);
      }

      widget.onTripUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Member "$memberEmail" removed from plan.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemovingMember = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final destination = (_trip['destination'] ?? 'Chosen Destination').toString();
    final tripName = (_trip['tripName'] ?? '$destination Trip').toString();
    final startDate = (_trip['startDate'] ?? 'N/A').toString();
    final endDate = (_trip['endDate'] ?? 'N/A').toString();
    final totalDays = _calculateDays();
    final groupSize = (_trip['groupSize'] ?? '1').toString();
    final placesList = ((_trip['places'] as List?) ?? []).map((e) => e.toString()).toList();

    // Stream for live Firestore sync on members
    final tripStream = _tripCode.isNotEmpty
        ? FirebaseFirestore.instance.collection('trips').doc(_tripCode).snapshots()
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Trip Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: tripStream,
        builder: (context, snapshot) {
          Map<String, dynamic> activeTripData = _trip;
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final cloudData = snapshot.data!.data();
            if (cloudData != null) {
              activeTripData = {..._trip, ...cloudData};
            }
          }

          // Extract members
          final List approvedMembers = (activeTripData['approvedMembers'] as List?) ??
              (activeTripData['members'] as List?) ??
              [];
          final String hostEmail = (activeTripData['userEmail'] ?? activeTripData['creatorEmail'] ?? '').toString().trim().toLowerCase();
          final String hostUid = (activeTripData['hostUid'] ?? '').toString();

          // Deduplicate and assemble members list
          final Map<String, Map<String, dynamic>> memberMapByEmail = {};
          
          // Host entry first
          if (hostEmail.isNotEmpty) {
            memberMapByEmail[hostEmail] = {
              'email': hostEmail,
              'displayName': 'Host (Organizer)',
              'uid': hostUid,
              'isHost': true,
            };
          }

          for (final m in approvedMembers) {
            if (m is Map) {
              final email = (m['email'] ?? '').toString().trim().toLowerCase();
              if (email.isNotEmpty) {
                final isHostMember = (email == hostEmail) || (hostUid.isNotEmpty && m['uid'] == hostUid);
                memberMapByEmail[email] = {
                  'email': email,
                  'displayName': (m['displayName'] ?? m['name'] ?? (isHostMember ? 'Host (Organizer)' : 'Traveler')).toString(),
                  'uid': (m['uid'] ?? '').toString(),
                  'photoUrl': m['photoUrl']?.toString(),
                  'isHost': isHostMember,
                  'raw': m,
                };
              }
            }
          }

          final membersList = memberMapByEmail.values.toList();
          final int memberCount = membersList.isNotEmpty ? membersList.length : int.tryParse(groupSize) ?? 1;

          // Schedules: Initial vs Replanned
          final initialSchedule = _getScheduleList(activeTripData['initialPlan'] ?? activeTripData['itineraryPlan']);
          final replannedSchedule = _getScheduleList(activeTripData['replannedPlan']);
          final bool hasReplan = replannedSchedule.isNotEmpty || (activeTripData['hasReplan'] == true);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO OVERVIEW CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.location_city_rounded, color: primaryColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destination,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                if (tripName != destination)
                                  Text(
                                    tripName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: subtextColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Saved Plan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 18),

                      // KEY STATS GRID (3 columns: Days, Dates, Places)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.calendar_month_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              label: 'Total Days',
                              value: '$totalDays ${totalDays == 1 ? 'Day' : 'Days'}',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.date_range_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              label: 'Date of Plan',
                              value: '$startDate - $endDate',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.place_rounded,
                              iconColor: const Color(0xFFEC4899),
                              label: 'Places Count',
                              value: '${placesList.length} Places',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 2. MEMBERS SECTION (COUNT + MAIL IDS + REMOVE OPTION)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Trip Members ($memberCount)',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    if (_isRemovingMember)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: membersList.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No members recorded. Host email: $hostEmail',
                            style: TextStyle(color: subtextColor, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: membersList.length,
                          separatorBuilder: (context, idx) => Divider(height: 1, color: borderColor),
                          itemBuilder: (context, idx) {
                            final member = membersList[idx];
                            final email = member['email']?.toString() ?? 'No Email';
                            final name = member['displayName']?.toString() ?? 'Traveler';
                            final bool isHost = member['isHost'] == true;
                            final String memberUid = member['uid']?.toString() ?? '';
                            final memberRaw = member['raw'] as Map<String, dynamic>? ?? {};

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isHost
                                        ? primaryColor.withValues(alpha: 0.15)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                    child: Icon(
                                      isHost ? Icons.star_rounded : Icons.person_rounded,
                                      color: isHost ? primaryColor : subtextColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isHost) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: primaryColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Host',
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: TextStyle(
                                            color: subtextColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Remove Member Option (Only for non-host members)
                                  if (!isHost)
                                    IconButton(
                                      tooltip: 'Remove member from plan',
                                      icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 20),
                                      onPressed: () => _removeMember(
                                        memberUid: memberUid,
                                        memberEmail: email,
                                        memberMap: memberRaw,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),

                // 3. PLACES TO VISIT SECTION
                Row(
                  children: [
                    Icon(Icons.tour_rounded, color: const Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Places to Visit (${placesList.length})',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: placesList.isEmpty
                      ? Text('No places added yet.', style: TextStyle(color: subtextColor, fontSize: 13))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: List.generate(placesList.length, (idx) {
                            final place = placesList[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    place,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                ),
                const SizedBox(height: 24),

                // 4. INITIAL PLAN & REPLAN DETAILS SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.route_rounded, color: const Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Trip Plan Schedule',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    if (hasReplan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Replanned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tab Switcher between Initial Plan and Replan Details
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: TabBar(
                    controller: _planTabController,
                    indicator: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: subtextColor,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Initial Plan'),
                      Tab(text: 'Replan Details'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tab View
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _planTabController,
                    children: [
                      // TAB 1: INITIAL PLAN
                      _buildScheduleView(
                        schedule: initialSchedule,
                        isDark: isDark,
                        emptyMessage: 'No initial schedule activities found.',
                        isReplanned: false,
                      ),

                      // TAB 2: REPLAN DETAILS
                      hasReplan
                          ? _buildScheduleView(
                              schedule: replannedSchedule.isNotEmpty ? replannedSchedule : initialSchedule,
                              isDark: isDark,
                              emptyMessage: 'No replan details recorded.',
                              isReplanned: true,
                            )
                          : Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.published_with_changes_rounded, size: 44, color: subtextColor.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No Replan Applied',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'This trip is currently running on its original schedule.\nWhen you replan on the map, updated timing and detours will appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView({
    required List<Map<String, dynamic>> schedule,
    required bool isDark,
    required String emptyMessage,
    required bool isReplanned,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (schedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(color: subtextColor, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: schedule.length,
      itemBuilder: (context, dIdx) {
        final day = schedule[dIdx];
        final dayTitle = (day['dayTitle'] ?? 'Day ${dIdx + 1}').toString();
        final rawActs = (day['activities'] as List?) ?? [];
        final activities = rawActs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: ExpansionTile(
            initiallyExpanded: dIdx == 0,
            shape: const Border(),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
              child: Text(
                '${dIdx + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            title: Text(
              dayTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              '${activities.length} planned stops',
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
            children: [
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No activities listed for this day.', style: TextStyle(color: subtextColor, fontSize: 12)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (ctx, idx) => Divider(height: 1, color: borderColor),
                  itemBuilder: (ctx, actIdx) {
                    final act = activities[actIdx];
                    final place = (act['place'] ?? 'Activity').toString();
                    final time = (act['time'] ?? '').toString();
                    final description = (act['activity'] ?? act['description'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isReplanned ? Icons.published_with_changes_rounded : Icons.schedule_rounded,
                            size: 16,
                            color: isReplanned ? const Color(0xFF8B5CF6) : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: Color(0xFF6366F1),
                                        ),
                                      ),
                                  ],
                                ),
                                if (description.isNotEmpty && description != place) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    style: TextStyle(fontSize: 11.5, color: subtextColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
