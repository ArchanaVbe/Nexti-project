import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Big Five Traits
  double _openness = 0.5;
  double _conscientiousness = 0.5;
  double _extraversion = 0.5;
  double _agreeableness = 0.5;
  double _neuroticism = 0.5;

  // POI Category Preferences (will be normalized to sum to 1)
  double _prefAdventure = 0.5;
  double _prefCultural = 0.5;
  double _prefNature = 0.5;
  double _prefRelaxation = 0.5;
  double _prefFood = 0.5;
  double _prefShopping = 0.5;
  double _prefHistorical = 0.5;

  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personality & Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Big Five Personality Traits',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Help NexTripia-AI tailor your travel experience to your personality.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTraitSlider('Openness', _openness, (val) {
                      setState(() => _openness = val);
                    }),
                    _buildTraitSlider('Conscientiousness', _conscientiousness, (val) {
                      setState(() => _conscientiousness = val);
                    }),
                    _buildTraitSlider('Extraversion', _extraversion, (val) {
                      setState(() => _extraversion = val);
                    }),
                    _buildTraitSlider('Agreeableness', _agreeableness, (val) {
                      setState(() => _agreeableness = val);
                    }),
                    _buildTraitSlider('Neuroticism', _neuroticism, (val) {
                      setState(() => _neuroticism = val);
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Budget Constraints',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Individual Budget (\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Travel Preferences',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Rate how much you enjoy each activity type. These will be used to personalize your itinerary.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTraitSlider('Adventure', _prefAdventure, (val) => setState(() => _prefAdventure = val)),
                    _buildTraitSlider('Cultural', _prefCultural, (val) => setState(() => _prefCultural = val)),
                    _buildTraitSlider('Nature', _prefNature, (val) => setState(() => _prefNature = val)),
                    _buildTraitSlider('Relaxation', _prefRelaxation, (val) => setState(() => _prefRelaxation = val)),
                    _buildTraitSlider('Food & Dining', _prefFood, (val) => setState(() => _prefFood = val)),
                    _buildTraitSlider('Shopping', _prefShopping, (val) => setState(() => _prefShopping = val)),
                    _buildTraitSlider('Historical', _prefHistorical, (val) => setState(() => _prefHistorical = val)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // Save profile logic placeholder
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile saved successfully!')),
                  );
                },
                child: const Text('Save Profile'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              const Text('Low', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
              const Text('High', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
