import 'package:clientapp/features/church/models/church_models.dart';

// Using existing meditation mp3s as placeholders so the UI is runnable.
// Replace with real sermon/story/sacrament audio later.

final List<ChurchCategory> kGenesisToExodus = [
  ChurchCategory(
    id: 'genesis',
    title: 'GENESIS TO\nEXODUS',
    items: [
      ChurchAudio(
        id: 'creation',
        title: 'Creation',
        duration: const Duration(minutes: 3, seconds: 45),
        asset: 'assets/sounds/meditation/normal_bg.mp3',
        imageAsset: 'assets/icon/app_icon.png',
      ),
      ChurchAudio(
        id: 'noah',
        title: "Noah's Ark",
        duration: const Duration(minutes: 4, seconds: 20),
        asset: 'assets/sounds/meditation/breathandpray_male.mp3',
        imageAsset: 'assets/icon/app_icon.png',
      ),
      // A few items with subitems reusing the same sample audio
      ChurchAudio(
        id: 'joseph',
        title: 'Joseph',
        duration: const Duration(minutes: 2, seconds: 58),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: const [
          SubAudio(
            id: 'dreams',
            title: 'Dreams',
            duration: Duration(minutes: 1, seconds: 12),
            asset: 'assets/sounds/meditation/breathin_female.mp3',
          ),
          SubAudio(
            id: 'pit',
            title: 'Thrown into the Pit',
            duration: Duration(minutes: 1, seconds: 37),
            asset: 'assets/sounds/meditation/breathout_female.mp3',
          ),
        ],
      ),
      ChurchAudio(
        id: 'moses',
        title: 'Moses',
        duration: const Duration(minutes: 3, seconds: 10),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: const [
          SubAudio(
            id: 'birth',
            title: 'Birth and Nile',
            duration: Duration(minutes: 0, seconds: 52),
            asset: 'assets/sounds/meditation/breathin_female.mp3',
          ),
          SubAudio(
            id: 'plagues',
            title: 'The Plagues',
            duration: Duration(minutes: 1, seconds: 4),
            asset: 'assets/sounds/meditation/breathout_female.mp3',
          ),
        ],
      ),
      ChurchAudio(
        id: 'bush',
        title: 'The Burning Bush',
        duration: const Duration(minutes: 2, seconds: 22),
        asset: 'assets/sounds/meditation/fire_breath_bg.mp3',
        imageAsset: 'assets/icon/app_icon.png',
      ),
      ChurchAudio(
        id: 'david',
        title: 'David and Goliath',
        duration: const Duration(minutes: 5, seconds: 7),
        asset: 'assets/sounds/meditation/welldone_male.mp3',
        imageAsset: 'assets/icon/app_icon.png',
      ),
    ],
  ),
];

final List<ChurchCategory> kKingsAndProphets = [
  ChurchCategory(
    id: 'stories',
    title: 'STORIES',
    items: const [
      ChurchAudio(
        id: 'daniel',
        title: 'Daniel in the Lions’ Den',
        duration: Duration(minutes: 3, seconds: 1),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'decree', title: 'The Decree', duration: Duration(seconds: 58), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'den', title: 'Thrown to the Lions', duration: Duration(minutes: 1, seconds: 8), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'jonah',
        title: 'Jonah and the Great Fish',
        duration: Duration(minutes: 2, seconds: 20),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'storm', title: 'The Storm', duration: Duration(seconds: 50), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'greatfish', title: 'Great Fish', duration: Duration(minutes: 1, seconds: 14), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'elijah',
        title: 'Elijah on Mount Carmel',
        duration: Duration(minutes: 3, seconds: 12),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'challenge', title: 'Challenge of Baal', duration: Duration(seconds: 46), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'fire', title: 'Fire from Heaven', duration: Duration(minutes: 1, seconds: 10), asset: 'assets/sounds/meditation/fire_breath_bg.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'esther',
        title: 'Queen Esther’s Courage',
        duration: Duration(minutes: 2, seconds: 48),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'mordecai', title: 'Mordecai’s plea', duration: Duration(seconds: 52), asset: 'assets/sounds/meditation/breathandpray_female.mp3'),
          SubAudio(id: 'banquet', title: 'The Banquet', duration: Duration(minutes: 1, seconds: 6), asset: 'assets/sounds/meditation/welldone_male.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'samuel',
        title: 'Samuel Hears God',
        duration: Duration(minutes: 2, seconds: 30),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'call', title: 'The Call', duration: Duration(seconds: 44), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'speak', title: 'Speak, Lord', duration: Duration(minutes: 1, seconds: 4), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'furnace',
        title: 'Fiery Furnace',
        duration: Duration(minutes: 2, seconds: 58),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'refuse', title: 'Refusing the Idol', duration: Duration(seconds: 48), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'deliver', title: 'Deliverance', duration: Duration(minutes: 1, seconds: 12), asset: 'assets/sounds/meditation/welldone_female.mp3'),
        ],
      ),
    ],
  ),
];

final List<ChurchCategory> kLifeOfChrist = [
  ChurchCategory(
    id: 'sacraments',
    title: 'SACRAMENTS',
    items: const [
      ChurchAudio(
        id: 'baptism',
        title: 'Baptism',
        duration: Duration(minutes: 2, seconds: 44),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'water', title: 'Water and Spirit', duration: Duration(seconds: 40), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'promise', title: 'Promise and New Life', duration: Duration(minutes: 1, seconds: 2), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'eucharist',
        title: 'Eucharist',
        duration: Duration(minutes: 3, seconds: 7),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'bread', title: 'Bread of Life', duration: Duration(seconds: 56), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'cup', title: 'Cup of Salvation', duration: Duration(minutes: 1, seconds: 6), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'confirmation',
        title: 'Confirmation',
        duration: Duration(minutes: 2, seconds: 36),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'seal', title: 'Seal of the Spirit', duration: Duration(seconds: 48), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'gifts', title: 'Gifts and Mission', duration: Duration(minutes: 1, seconds: 6), asset: 'assets/sounds/meditation/welldone_male.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'reconciliation',
        title: 'Reconciliation',
        duration: Duration(minutes: 2, seconds: 50),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'contrition', title: 'Contrition', duration: Duration(seconds: 46), asset: 'assets/sounds/meditation/breathandpray_male.mp3'),
          SubAudio(id: 'absolve', title: 'Absolution', duration: Duration(minutes: 1, seconds: 8), asset: 'assets/sounds/meditation/welldone_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'anointing',
        title: 'Anointing of the Sick',
        duration: Duration(minutes: 2, seconds: 40),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'comfort', title: 'Comfort and Strength', duration: Duration(seconds: 44), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'healing', title: 'Healing Grace', duration: Duration(minutes: 1, seconds: 4), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'holyorders',
        title: 'Holy Orders',
        duration: Duration(minutes: 3, seconds: 2),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'call', title: 'Call to Serve', duration: Duration(seconds: 52), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'mission', title: 'Mission and Sacrifice', duration: Duration(minutes: 1, seconds: 12), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
      ChurchAudio(
        id: 'matrimony',
        title: 'Matrimony',
        duration: Duration(minutes: 2, seconds: 58),
        imageAsset: 'assets/icon/app_icon.png',
        subAudios: [
          SubAudio(id: 'covenant', title: 'Covenant of Love', duration: Duration(seconds: 50), asset: 'assets/sounds/meditation/breathin_female.mp3'),
          SubAudio(id: 'unity', title: 'Unity and Grace', duration: Duration(minutes: 1, seconds: 10), asset: 'assets/sounds/meditation/breathout_female.mp3'),
        ],
      ),
    ],
  ),
];
