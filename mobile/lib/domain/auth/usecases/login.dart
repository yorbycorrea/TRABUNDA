import 'package:mobile/data/auth/entities/app_user.dart';
import 'package:mobile/domain/auth/repositories/auth_repository.dart';

class Login {
  final AuthRepository _repository;

  Login(this._repository);

  Future<AppUser> call({required String username, required String password}) {
    return _repository.login(username: username, password: password);
  }
}
