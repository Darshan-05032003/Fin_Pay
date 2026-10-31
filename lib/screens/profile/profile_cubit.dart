import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the logout flow is.
enum LogoutStatus {
  idle,

  /// The confirmation sheet is open.
  confirming,
  signingOut,

  /// The session is cleared; the router redirects to login.
  signedOut,
  failed,
}

/// Owns the profile tab's logout flow: confirm → sign out once → done.
/// A second confirm while one is in flight is ignored.
class ProfileCubit extends Cubit<LogoutStatus> {
  ProfileCubit({required SessionCubit session})
    : _session = session,
      super(LogoutStatus.idle);

  final SessionCubit _session;

  /// The confirmation sheet opened.
  void startLogout() {
    if (state == LogoutStatus.signingOut) return;
    emit(LogoutStatus.confirming);
  }

  /// The sheet was dismissed without confirming.
  void cancelLogout() {
    if (state == LogoutStatus.confirming || state == LogoutStatus.failed) {
      emit(LogoutStatus.idle);
    }
  }

  /// Clears the session. The user row stays on the device.
  Future<void> confirmLogout() async {
    if (state == LogoutStatus.signingOut || state == LogoutStatus.signedOut) {
      return;
    }
    emit(LogoutStatus.signingOut);
    try {
      await _session.signOut();
      if (!isClosed) emit(LogoutStatus.signedOut);
    } on Exception {
      if (!isClosed) emit(LogoutStatus.failed);
    }
  }
}
