#!/usr/bin/env ruby

require 'json'
require 'net/https'
require 'base64'
require 'fileutils'

ADDRESS = URI(ARGV[0])

payload = Net::HTTP::get(ADDRESS)
j = JSON.parse(payload)

FILENAME = j['clip_id'] + '.mp4'
AUDIO_FILENAME = j['clip_id'] + '_audio.mp4'
VIDEO_FILENAME = j['clip_id'] + '_video.mp4'
BASE_URL = ADDRESS + j['base_url']

# Determine highest bitrate stream
stream_index = 0
stream_id = ''
highest_bitrate = 0
j['video'].each_index do |i|
  v = j['video'][i]

  if v['bitrate'] > highest_bitrate
    highest_bitrate = v['bitrate']
    stream_index = i
    stream_id = v['id']
  end
end

puts "Selecting stream ID #{stream_id} at v/a bitrates #{highest_bitrate}/#{j['audio'][stream_index]['bitrate']}"

# Decode and write out the init segments. There are two separate streams that
# need to be muxed later.
f_audio = File.open(AUDIO_FILENAME, 'w')
f_audio.write(Base64::decode64(j['audio'][stream_index]['init_segment']))
f_video = File.open(VIDEO_FILENAME, 'w')
f_video.write(Base64::decode64(j['video'][stream_index]['init_segment']))


# Iterate through segments, downloading and writing them out.
# Audio and video base URLs are different.
SEGMENT_COUNT = j['video'][stream_index]['segments'].count
AUDIO_BASE_URL = BASE_URL + j['audio'][stream_index]['base_url']
VIDEO_BASE_URL = BASE_URL + j['video'][stream_index]['base_url']

SEGMENT_COUNT.times do |i|
  this_video = VIDEO_BASE_URL + j['video'][stream_index]['segments'][i]['url']
  this_audio = AUDIO_BASE_URL + j['audio'][stream_index]['segments'][i]['url']

  puts "# Segment #{i}"
  puts " - retrieving video #{this_video}"
  vsegment = Net::HTTP::get(this_video)
  f_video.write(vsegment)

  puts " - retrieving audio #{this_audio}"
  asegment = Net::HTTP::get(this_audio)
  f_audio.write(asegment)

  puts ''
end

puts 'Closing output files and multiplexing with ffmpeg...'
f_audio.close
f_video.close
system('ffmpeg', '-y', '-i', VIDEO_FILENAME, '-i', AUDIO_FILENAME, '-codec', 'copy', FILENAME)

# Cleanup and exit
FileUtils.rm(AUDIO_FILENAME)
FileUtils.rm(VIDEO_FILENAME)

puts "Wrote output to #{FILENAME}"
