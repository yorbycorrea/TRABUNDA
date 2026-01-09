class FakeTokenStorage {
  FakeTokenStorage({this.access});

  final String? access;

  Future<String?> readAccess() async => access;
}
