import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

abstract class CardEvent extends Equatable {
  const CardEvent();

  @override
  List<Object?> get props => [];
}

class LoadCardRequested extends CardEvent {}

class RefreshCardRequested extends CardEvent {}

abstract class CardState extends Equatable {
  const CardState();

  @override
  List<Object?> get props => [];
}

class CardInitial extends CardState {}

class CardLoading extends CardState {}

class CardLoaded extends CardState {
  final Map<String, dynamic> card;

  const CardLoaded(this.card);

  @override
  List<Object?> get props => [card];
}

class CardError extends CardState {
  final String message;

  const CardError(this.message);

  @override
  List<Object?> get props => [message];
}

class CardBloc extends Bloc<CardEvent, CardState> {
  CardBloc() : super(CardInitial()) {
    on<LoadCardRequested>((event, emit) async {
      emit(CardLoading());
      emit(
        const CardLoaded({
          "card_number": "CARD_DEMO",
          "balance": "0.00",
          "level": "standard",
          "qr_code_data": "BONUS:CARD_DEMO:UUID",
        }),
      );
    });

    on<RefreshCardRequested>((event, emit) async {
      emit(state);
    });
  }
}