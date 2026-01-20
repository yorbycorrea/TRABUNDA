import 'package:mobile/data/auth/entities/app_user.dart';
import 'package:mobile/domain/auth/repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository _repository;

  GetCurrentUser(this._repository);

  Future<AppUser?> call() {
    return _repository.getCurrentUser();
  }
}
