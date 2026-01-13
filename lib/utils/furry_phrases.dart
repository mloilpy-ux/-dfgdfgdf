import 'dart:math';

class FurryPhrases {
  static final _random = Random();
  
  static const List<String> loading = [
    'OwO Loading...',
    'UwU Fetching arts...',
    '*wags tail*',
    'Getting floofy content...',
    'Pawsing... 🐾',
    'rawr! Loading...',
    '*nuzzles server*',
  ];
  
  static const List<String> success = [
    'Yay! UwU',
    'Got it! OwO',
    '*happy tail wags*',
    'Success! 🐾',
    'Awoo!',
  ];
  
  static const List<String> error = [
    'Oopsie >w<',
    'Sowwy...',
    '*sad tail droops*',
    'Nu! Error :c',
    'Failed ówò',
  ];
  
  static String randomLoading() => loading[_random.nextInt(loading.length)];
  static String randomSuccess() => success[_random.nextInt(success.length)];
  static String randomError() => error[_random.nextInt(error.length)];
}
