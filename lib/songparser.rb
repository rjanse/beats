class SongParseError < RuntimeError; end

class SongParser  
  def initialize()
  end
      
  def parse(base_path, definition = nil)
    if(definition.class == String)
      begin
        raw_song_definition = YAML.load(definition)
      rescue ArgumentError => detail
        raise SongParseError, "Syntax error in YAML file"
      end
    elsif(definition.class == Hash)
      raw_song_definition = definition
    else
      raise SongParseError, "Invalid song input"
    end
    raw_song_components = split_raw_yaml_into_components(raw_song_definition)
    
    song = Song.new(base_path)
    
    # 1.) Set tempo
    begin
      song.tempo = raw_song_components[:tempo]
    rescue InvalidTempoError => detail
      raise SongParseError, "#{detail}"
    end
    
    # 2.) Build kit
    begin
      kit = build_kit(base_path, raw_song_components[:kit], raw_song_components[:patterns])
    rescue SoundNotFoundError => detail
      raise SongParseError, "#{detail}"
    end
    song.kit = kit
    
    # 3.) Load patterns
    raw_song_components[:patterns].keys.each{|key|
      new_pattern = song.pattern key.to_sym

      track_list = raw_song_components[:patterns][key]
      track_list.each{|track_definition|
        track_name = track_definition.keys.first
        new_pattern.track track_name, kit.get_sample_data(track_name), track_definition[track_name]
      }
    }
    
    # 4.) Set structure
    structure = []
    raw_song_components[:structure].each{|pattern_item|
      if(pattern_item.class == String)
        pattern_item = {pattern_item => "x1"}
      end
      
      pattern_name = pattern_item.keys.first
      pattern_name_sym = pattern_name.downcase.to_sym
      
      if(!song.patterns.has_key?(pattern_name_sym))
        raise SongParseError, "Song structure includes non-existant pattern: #{pattern_name}."
      end
      
      # Convert the number of repeats from a String such as "x4" into an integer such as 4.
      multiples_str = pattern_item[pattern_name]
      multiples_str.slice!(0)
      multiples = multiples_str.to_i
      
      if(multiples_str.match(/[^0-9]/) != nil)
        raise SongParseError, "'#{multiples_str}' is an invalid number of repeats for pattern '#{pattern_name}'. Number of repeats should be a whole number."
      elsif(multiples < 0)
        raise SongParseError, "'#{multiples_str}' is an invalid number of repeats for pattern '#{pattern_name}'. Must be 0 or greater."
      end
      
      multiples.times { structure << pattern_name_sym }
    }
    song.structure = structure
    
    return song
  end
  
private
  def split_raw_yaml_into_components(raw_song_definition)
    raw_song_components = {}
  
    raw_song_components[:full_definition] = downcase_hash_keys(raw_song_definition)
    raw_song_components[:header]          = downcase_hash_keys(raw_song_components[:full_definition]["song"])
    raw_song_components[:tempo]           = raw_song_components[:header]["tempo"]
    raw_song_components[:kit]             = raw_song_components[:header]["kit"]
    raw_song_components[:structure]       = raw_song_components[:header]["structure"]
    raw_song_components[:patterns]        = raw_song_components[:full_definition].reject {|k, v| k == "song"}
  
    return raw_song_components
  end
    
  def build_kit(base_path, raw_kit, raw_patterns)
    kit = Kit.new(base_path)
    
    # Add sounds defined in the Kit section of the song header
    if(raw_kit != nil)
      raw_kit.each {|kit_item|
        kit.add(kit_item.keys.first, kit_item.values.first)
      }
    end
    
    # TODO Investigate detecting duplicate keys already defined in the Kit section
    # Add sounds not defined in Kit section, but used in individual tracks
    raw_patterns.keys.each{|key|
      track_list = raw_patterns[key]
      track_list.each{|track_definition|
        track_name = track_definition.keys.first
        track_path = track_name
        
        kit.add(track_name, track_path)
      }
    }
    
    return kit
  end
    
  # Converts all hash keys to be lowercase
  def downcase_hash_keys(hash)
    return hash.inject({}) {|new_hash, pair|
        new_hash[pair.first.downcase] = pair.last
        new_hash
    }
  end
end