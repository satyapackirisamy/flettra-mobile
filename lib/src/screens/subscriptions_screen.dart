import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _plans = [];
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _user = await _authService.getUser();
    await _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getSubscriptionPlans();
      setState(() => _plans = res.data.where((p) => p['isActive'] == true).toList());
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(Map<String, dynamic> plan) async {
    try {
      final expiry = DateTime.now().add(Duration(days: plan['durationDays']));
      await _apiService.subscribeToPlan(_user!['id'], plan['name'], expiry);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success! 🎉'),
            content: Text('You are now subscribed to ${plan['name']}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Great!')),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        title: const Text('Society Access', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              itemCount: _plans.length,
              itemBuilder: (context, index) => _buildPlanCard(_plans[index]),
            ),
          ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final bool isPremium = plan['name'].toString().toLowerCase().contains('premium');

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: isPremium ? const Color(0xFF4F46E5).withOpacity(0.3) : const Color(0xFFF1F5F9), width: isPremium ? 2 : 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 30, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name'].toString().toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isPremium ? const Color(0xFF4F46E5) : Colors.grey[400], letterSpacing: 2.0)),
                const SizedBox(height: 12),
                Text(plan['description'], style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: "₹${plan['price']}", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -1.0)),
                      TextSpan(text: " / ${plan['durationDays']}d", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('BENEFITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 2.0)),
                const SizedBox(height: 16),
                ... (plan['features'] as List).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 13))),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _subscribe(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPremium ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('ACTIVATE PLAN', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          if (isPremium)
            Positioned(
              top: -12,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}
