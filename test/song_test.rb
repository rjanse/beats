$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/includes'

class SongTest < Test::Unit::TestCase
  DEFAULT_TEMPO = 120
  
  def generate_test_data
    kit = Kit.new("test/sounds", {"bass.wav"      => "bass_mono_8.wav",
                                  "snare.wav"     => "snare_mono_8.wav",
                                  "hh_closed.wav" => "hh_closed_mono_8.wav",
                                  "ride.wav"      => "ride_mono_8.wav"})
    
    test_songs = {}
    base_path = File.dirname(__FILE__) + "/.."

    test_songs[:blank] = Song.new(base_path)
    
    test_songs[:no_flow] = Song.new(base_path)
    verse = test_songs[:no_flow].pattern :verse
    verse.track "bass.wav",      kit.get_sample_data("bass.wav"),      "X.......X......."
    verse.track "snare.wav",     kit.get_sample_data("snare.wav"),     "....X.......X..."
    verse.track "hh_closed.wav", kit.get_sample_data("hh_closed.wav"), "X.X.X.X.X.X.X.X."
    
    test_songs[:repeats_not_specified] = SongParser.new().parse(base_path, YAML.load_file("test/fixtures/valid/repeats_not_specified.txt"))
    test_songs[:overflow] = SongParser.new().parse(base_path, YAML.load_file("test/fixtures/valid/pattern_with_overflow.txt"))
    test_songs[:from_valid_yaml_string] = SongParser.new().parse(base_path, YAML.load_file("test/fixtures/valid/example_no_kit.txt"))
    test_songs[:from_valid_yaml_string_with_kit] = SongParser.new().parse(base_path, YAML.load_file("test/fixtures/valid/example_with_kit.txt"))
    
    test_songs[:from_code] = Song.new(base_path)
    verse = test_songs[:from_code].pattern :verse
    verse.track "bass.wav",      kit.get_sample_data("bass.wav"),      "X.......X......."
    verse.track "snare.wav",     kit.get_sample_data("snare.wav"),     "....X.......X..."
    verse.track "hh_closed.wav", kit.get_sample_data("hh_closed.wav"), "X.X.X.X.X.X.X.X."
    chorus = test_songs[:from_code].pattern :chorus
    chorus.track "bass.wav",  kit.get_sample_data("bass.wav"),  "X......."
    chorus.track "snare.wav", kit.get_sample_data("snare.wav"), "....X..X"
    chorus.track "ride.wav",  kit.get_sample_data("ride.wav"),  "X.....X."
    test_songs[:from_code].flow = [:verse, :chorus, :verse, :chorus, :chorus]
    test_songs[:from_code].kit = kit
    
    return test_songs
  end
    
  def test_initialize
    test_songs = generate_test_data()
    
    assert_equal([], test_songs[:blank].flow)
    assert_equal((Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0,
                 test_songs[:blank].tick_sample_length)
    
    assert_equal([], test_songs[:no_flow].flow)
    assert_equal((Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0,
                 test_songs[:no_flow].tick_sample_length)
    
    assert_equal([:verse, :chorus, :verse, :chorus, :chorus], test_songs[:from_code].flow)
    assert_equal((Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0,
                 test_songs[:from_code].tick_sample_length)
  end
  
  def test_total_tracks
    test_songs = generate_test_data()
    
    assert_equal(0, test_songs[:blank].total_tracks)
    assert_equal(3, test_songs[:no_flow].total_tracks)
    assert_equal(3, test_songs[:from_code].total_tracks)
    assert_equal(1, test_songs[:repeats_not_specified].total_tracks)
    assert_equal(1, test_songs[:overflow].total_tracks)
    assert_equal(5, test_songs[:from_valid_yaml_string].total_tracks)
  end
  
  def test_track_names
    test_songs = generate_test_data()
    
    assert_equal([], test_songs[:blank].track_names)
    assert_equal(["bass.wav", "hh_closed.wav", "snare.wav"], test_songs[:no_flow].track_names)
    assert_equal(["bass.wav", "hh_closed.wav", "ride.wav", "snare.wav"], test_songs[:from_code].track_names)
    assert_equal(["test/sounds/bass_mono_8.wav"], test_songs[:repeats_not_specified].track_names)
    assert_equal(["test/sounds/snare_mono_8.wav"], test_songs[:overflow].track_names)
    assert_equal(["test/sounds/bass_mono_8.wav",
                  "test/sounds/hh_closed_mono_8.wav",
                  "test/sounds/hh_open_mono_8.wav",
                  "test/sounds/ride_mono_8.wav",
                  "test/sounds/snare_mono_8.wav"],
                  test_songs[:from_valid_yaml_string].track_names)
    assert_equal(["bass",
                  "hhclosed",
                  "hhopen",
                  "snare",
                  "test/sounds/hh_closed_mono_8.wav",
                  "test/sounds/ride_mono_8.wav"],
                  test_songs[:from_valid_yaml_string_with_kit].track_names)
  end
  
  def test_sample_length
    test_songs = generate_test_data()

    assert_equal(0, test_songs[:blank].sample_length)
    assert_equal(0, test_songs[:no_flow].sample_length)
    
    assert_equal((test_songs[:from_code].tick_sample_length * 16 * 2) +
                     (test_songs[:from_code].tick_sample_length * 8 * 3),
                 test_songs[:from_code].sample_length)
                            
    assert_equal(test_songs[:repeats_not_specified].tick_sample_length,
                 test_songs[:repeats_not_specified].sample_length)
                            
    assert_equal(test_songs[:overflow].tick_sample_length * 8, test_songs[:overflow].sample_length)
  end
  
  def test_sample_length_with_overflow
    test_songs = generate_test_data()
    
    assert_equal(0, test_songs[:blank].sample_length_with_overflow)
    assert_equal(0, test_songs[:no_flow].sample_length_with_overflow)
    
    snare_overflow =
      (test_songs[:from_code].kit.get_sample_data("snare.wav").length -
       test_songs[:from_code].tick_sample_length).ceil   
    assert_equal(test_songs[:from_code].sample_length + snare_overflow, test_songs[:from_code].sample_length_with_overflow)    
    
    assert_equal(test_songs[:repeats_not_specified].tick_sample_length,
                 test_songs[:repeats_not_specified].sample_length_with_overflow)
    
    snare_overflow =
      (test_songs[:overflow].kit.get_sample_data("test/sounds/snare_mono_8.wav").length -
       test_songs[:overflow].tick_sample_length).ceil
    assert_equal((test_songs[:overflow].tick_sample_length * 8) + snare_overflow,
                 test_songs[:overflow].sample_length_with_overflow)
    
    snare_overflow =
      (test_songs[:from_valid_yaml_string].kit.get_sample_data("test/sounds/snare_mono_8.wav").length -
       test_songs[:from_valid_yaml_string].tick_sample_length).ceil
    assert_equal(test_songs[:from_valid_yaml_string].sample_length + snare_overflow,
                 test_songs[:from_valid_yaml_string].sample_length_with_overflow)
  end
  
  def test_copy_ignoring_patterns_and_flow
    test_songs = generate_test_data()
    original_song = test_songs[:from_valid_yaml_string]
    cloned_song = original_song.copy_ignoring_patterns_and_flow()
    
    assert_not_equal(cloned_song, original_song)
    assert_equal(cloned_song.tempo, original_song.tempo)
    assert_equal(cloned_song.kit, original_song.kit)
    assert_equal(cloned_song.tick_sample_length, original_song.tick_sample_length)
    assert_equal([], cloned_song.flow)
    assert_equal({}, cloned_song.patterns)
  end
  
  def test_split
    test_songs = generate_test_data()
    split_songs = test_songs[:from_valid_yaml_string_with_kit].split()
    
    assert_equal(Hash, split_songs.class)
    assert_equal(6, split_songs.length)
    
    song_names = split_songs.keys.sort
    assert_equal(["bass",
                  "hhclosed",
                  "hhopen",
                  "snare",
                  "test/sounds/hh_closed_mono_8.wav",
                  "test/sounds/ride_mono_8.wav"],
                 song_names)
                 
    song_names.each do |song_name|
      song = split_songs[song_name]
      assert_equal(99, song.tempo)
      assert_equal(3, song.patterns.length)
      assert_equal([:verse, :verse, :chorus, :chorus, :verse, :verse, :chorus, :chorus, :chorus, :chorus,
                    :bridge, :chorus, :chorus, :chorus, :chorus],
                   song.flow)
                   
      song.patterns.each do |pattern_name, pattern|
        assert_equal(1, pattern.tracks.length)
        assert_equal([song_name], pattern.tracks.keys)
        assert_equal(song_name, pattern.tracks[song_name].name)
      end
    end
    
    
  end
  
  def test_remove_unused_patterns
    test_songs = generate_test_data()
    
    assert_equal(1, test_songs[:no_flow].patterns.length)
    test_songs[:no_flow].remove_unused_patterns()
    assert_equal({}, test_songs[:no_flow].patterns)
    
    assert_equal(3, test_songs[:from_valid_yaml_string].patterns.length)
    test_songs[:from_valid_yaml_string].remove_unused_patterns()
    assert_equal(3, test_songs[:from_valid_yaml_string].patterns.length)
    assert_equal(Hash, test_songs[:from_valid_yaml_string].patterns.class)
  end
  
  def test_to_yaml
    test_songs = generate_test_data()
    result = test_songs[:from_valid_yaml_string_with_kit].to_yaml
    
    assert_equal(File.read("test/fixtures/yaml/song_yaml.txt"), result)
  end
end