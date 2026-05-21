import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryRequested extends HistoryEvent {}

class LoadMoreRequested extends HistoryEvent {}

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<Map<String, dynamic>> transactions;

  const HistoryLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class HistoryError extends HistoryState {
  final String message;

  const HistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc() : super(HistoryInitial()) {
    on<LoadHistoryRequested>((event, emit) async {
      emit(HistoryLoading());
      emit(const HistoryLoaded([]));
    });

    on<LoadMoreRequested>((event, emit) async {
      emit(state);
    });
  }
}