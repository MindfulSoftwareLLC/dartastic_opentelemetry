void main() {
  void noOp(_) {}
  final Function savedFunc = noOp;

  print('noOp is print: ${noOp == print}');
  print('noOp != print: ${noOp != print}');
  print('savedFunc is print: ${savedFunc == print}');
  print('savedFunc != print: ${savedFunc != print}');
}
