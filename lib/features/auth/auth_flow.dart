import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the three auth screens hand to each other: phone -> code -> profile.
/// Kept in memory only; the code is never written to disk.
class AuthFlowState {
  const AuthFlowState({this.phone, this.otp, this.resendIn = 0});

  /// +91XXXXXXXXXX once the SMS was requested.
  final String? phone;

  /// Set once the backend accepted the code and wants the profile of a new user.
  final String? otp;

  /// Seconds before another SMS may be requested, as told by the backend.
  final int resendIn;
}

class AuthFlow extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  void codeSent(String phone, int resendIn) =>
      state = AuthFlowState(phone: phone, resendIn: resendIn);

  void profileNeeded(String otp) =>
      state = AuthFlowState(phone: state.phone, otp: otp, resendIn: state.resendIn);

  void reset() => state = const AuthFlowState();
}

final authFlowProvider = NotifierProvider<AuthFlow, AuthFlowState>(AuthFlow.new);
