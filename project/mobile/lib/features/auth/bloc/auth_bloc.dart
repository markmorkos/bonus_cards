import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String? phone;

  const RegisterRequested(this.email, this.password, this.fullName, this.phone);

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class LogoutRequested extends AuthEvent {}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String token;

  const AuthAuthenticated(this.token);

  @override
  List<Object?> get props => [token];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      emit(const AuthAuthenticated("mock-token"));
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      emit(const AuthAuthenticated("mock-token"));
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthUnauthenticated());
    });
  }
}