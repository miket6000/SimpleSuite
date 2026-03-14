const baseFrequencyHz = 434000000;
const channelSpacingHz = 100000; // 100 kHz

class Channel {
  final int number;
  final String name;
  final Map<String, dynamic> presetValues;

  const Channel({
    required this.number,
    required this.name,
    required this.presetValues,
  });
}

final List<Channel> channels = List.generate(25, (i) { 
  final freq = baseFrequencyHz + channelSpacingHz * i;
  return Channel (
    number: i,
    name: "CH$i (${(freq/1000000).toStringAsFixed(3)} Mhz)", 
    presetValues: {
      'f': freq,
      's': 9,
      'b': 4,
      'c': 1
    }
  );
});
