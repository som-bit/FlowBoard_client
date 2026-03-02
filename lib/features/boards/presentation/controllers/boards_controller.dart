import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../database/database.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/board_repository.dart';

final boardsStreamProvider = StreamProvider.autoDispose<List<Board>>((ref) {
  final repository = ref.watch(boardRepositoryProvider);
  return repository.watchBoards();
});

final boardsControllerProvider = Provider.autoDispose<BoardsActionController>((
  ref,
) {
  final repository = ref.watch(boardRepositoryProvider);
  final currentUser = ref.watch(authControllerProvider).value;

  return BoardsActionController(repository, currentUser?.id ?? 'unknown_user');
});

class BoardsActionController {
  final BoardRepository _repository;
  final String _currentUserId;

  BoardsActionController(this._repository, this._currentUserId);

  Future<void> createNewBoard(String title, String color) async {
    await _repository.createBoard(title, color, _currentUserId);
  }

  Future<void> deleteBoard(String boardId) async {
    await _repository.deleteBoard(boardId);
  }

  Future<void> updateBoard(String boardId, String title, String color) async {
    await _repository.updateBoard(boardId, title, color);
  }
}
