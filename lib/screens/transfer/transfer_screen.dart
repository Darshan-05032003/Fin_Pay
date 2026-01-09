import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/user_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/skeleton_loader_full.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/cred_number_counter.dart';
import '../../widgets/animations/spring_animation.dart';
import '../../widgets/animations/pulse_animation.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? selectedRecipient;
  double _balance = 0.0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> recipients = [
    {'name': 'Kelvin Habit', 'account': '**** 5961', 'avatar': 'K'},
    {'name': 'John Doe', 'account': '**** 1234', 'avatar': 'J'},
    {'name': 'Jane Smith', 'account': '**** 5678', 'avatar': 'J'},
    {'name': 'Mike Johnson', 'account': '**** 9012', 'avatar': 'M'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await UserService.getBalance();
    setState(() {
      _balance = balance;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.credBlack,
        appBar: AppBar(
          title: const Text('Transfer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const SkeletonList(itemCount: 3),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.credBlack,
      appBar: AppBar(
        title: const Text('Transfer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredSlideIn(
              delay: const Duration(milliseconds: 100),
              offset: const Offset(0, 20),
              child: Row(
                children: [
                  CredButtonPress(
                    onTap: () async {
                      await HapticService.mediumImpact();
                      // Add recipient functionality
                    },
                    child: CredCardReveal(
                      duration: const Duration(milliseconds: 400),
                      perspective: 0.0008,
                      child: _buildAddRecipientButton(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: recipients.length,
                        itemBuilder: (context, index) {
                          final recipient = recipients[index];
                          final isSelected = selectedRecipient == recipient['name'];
                          return CredSlideIn(
                            delay: Duration(milliseconds: 150 + (index * 50)),
                            offset: const Offset(20, 0),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: CredButtonPress(
                                onTap: () async {
                                  await HapticService.selection();
                                  setState(() {
                                    selectedRecipient = recipient['name'];
                                  });
                                },
                                child: SpringAnimation(
                                  startOffset: const Offset(0, 10),
                                  endOffset: Offset.zero,
                                  child: PulseAnimation(
                                    duration: const Duration(seconds: 2),
                                    minScale: isSelected ? 0.98 : 1.0,
                                    maxScale: isSelected ? 1.02 : 1.0,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.credPurple
                                            : AppTheme.credGray,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.credPurple
                                              : AppTheme.credLightGray.withOpacity(0.3),
                                          width: isSelected ? 3 : 2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.credPurple.withOpacity(0.4),
                                                  blurRadius: 12,
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          recipient['avatar'],
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppTheme.credWhite
                                                : AppTheme.credTextPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedRecipient != null) ...[
              const SizedBox(height: 24),
              CredSlideIn(
                delay: const Duration(milliseconds: 300),
                offset: const Offset(0, 20),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 500),
                  perspective: 0.0008,
                  child: _buildSelectedRecipient(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 200),
              offset: const Offset(0, 30),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Focus(
                      child: Builder(
                        builder: (context) {
                          final hasFocus = Focus.of(context).hasFocus;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.credGray,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: hasFocus
                                    ? AppTheme.credPurple
                                    : AppTheme.credLightGray.withOpacity(0.2),
                                width: hasFocus ? 2 : 1,
                              ),
                            ),
                            child: TextField(
                              controller: _amountController,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.credPurple,
                                letterSpacing: -1,
                              ),
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '\$',
                                prefixStyle: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.credPurple,
                                  letterSpacing: -1,
                                ),
                                border: InputBorder.none,
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  fontSize: 42,
                                  color: AppTheme.credPurple.withOpacity(0.3),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    CredSlideIn(
                      delay: const Duration(milliseconds: 400),
                      offset: const Offset(0, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Your Balance: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.credTextSecondary,
                            ),
                          ),
                          CredNumberCounter(
                            value: _balance,
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.credPurple,
                            ),
                            prefix: '\$',
                            suffix: ' (Available)',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 500),
              offset: const Offset(0, 30),
              child: CredButtonPress(
                onTap: selectedRecipient != null && _amountController.text.isNotEmpty
                    ? () async {
                        final amount = double.tryParse(_amountController.text);
                        if (amount == null || amount <= 0) {
                          await HapticService.error();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                              backgroundColor: AppTheme.credRed,
                            ),
                          );
                          return;
                        }
                        if (amount > _balance) {
                          await HapticService.error();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Insufficient balance'),
                              backgroundColor: AppTheme.credRed,
                            ),
                          );
                          return;
                        }

                        await HapticService.mediumImpact();
                        final recipient = recipients.firstWhere(
                          (r) => r['name'] == selectedRecipient,
                        );
                        Navigator.pushNamed(
                          context,
                          '/transfer-review',
                          arguments: {
                            'recipientName': selectedRecipient!,
                            'recipientAccount': recipient['account'],
                            'amount': amount.toStringAsFixed(2),
                          },
                        );
                      }
                    : null,
                child: SpringAnimation(
                  startOffset: const Offset(0, 20),
                  endOffset: Offset.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: (selectedRecipient != null && _amountController.text.isNotEmpty)
                          ? AppTheme.credPurpleGradient
                          : null,
                      color: (selectedRecipient != null && _amountController.text.isNotEmpty)
                          ? null
                          : AppTheme.credGray,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (selectedRecipient != null && _amountController.text.isNotEmpty)
                          ? [
                              BoxShadow(
                                color: AppTheme.credPurple.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: (selectedRecipient != null && _amountController.text.isNotEmpty)
                              ? AppTheme.credWhite
                              : AppTheme.credTextSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildNumericKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRecipientButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppTheme.credPurpleGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.credPurple.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Icon(
        Icons.add,
        color: AppTheme.credWhite,
        size: 28,
      ),
    );
  }

  Widget _buildSelectedRecipient() {
    final recipient = recipients.firstWhere(
      (r) => r['name'] == selectedRecipient,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.credGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.credPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PulseAnimation(
            duration: const Duration(seconds: 2),
            minScale: 0.98,
            maxScale: 1.02,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.credPurpleGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credPurple.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  recipient['avatar'],
                  style: const TextStyle(
                    color: AppTheme.credWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.credTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  recipient['account'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.credTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          CredButtonPress(
            onTap: () async {
              await HapticService.lightImpact();
              setState(() {
                selectedRecipient = null;
                _amountController.clear();
              });
            },
            child: TextButton(
              onPressed: null,
              child: const Text(
                'Change',
                style: TextStyle(
                  color: AppTheme.credPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return CredSlideIn(
      delay: const Duration(milliseconds: 600),
      offset: const Offset(0, 40),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2,
        children: [
          _buildKeypadButton('1', 0),
          _buildKeypadButton('2', 1),
          _buildKeypadButton('3', 2),
          _buildKeypadButton('4', 3),
          _buildKeypadButton('5', 4),
          _buildKeypadButton('6', 5),
          _buildKeypadButton('7', 6),
          _buildKeypadButton('8', 7),
          _buildKeypadButton('9', 8),
          _buildKeypadButton('.', 9),
          _buildKeypadButton('0', 10),
          _buildKeypadButton('⌫', 11, isBackspace: true),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String text, int index, {bool isBackspace = false}) {
    return CredSlideIn(
      delay: Duration(milliseconds: 700 + (index * 30)),
      offset: const Offset(0, 20),
      child: CredButtonPress(
        onTap: () async {
          await HapticService.selection();
          if (isBackspace) {
            if (_amountController.text.isNotEmpty) {
              setState(() {
                _amountController.text =
                    _amountController.text.substring(0, _amountController.text.length - 1);
              });
            }
          } else {
            setState(() {
              final currentText = _amountController.text;
              if (text == '.' && currentText.contains('.')) {
                return;
              }
              _amountController.text = currentText + text;
            });
          }
        },
        child: CredCardReveal(
          duration: const Duration(milliseconds: 300),
          perspective: 0.0006,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.credGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.credLightGray.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isBackspace ? AppTheme.credRed : AppTheme.credTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
