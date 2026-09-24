package funkin.audio;

import flixel.sound.FlxSound;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
import lime.utils.UInt8Array;
#if (sys && lime_vorbis)
import lime.media.vorbis.Vorbis;
import lime.media.vorbis.VorbisFile;
import sys.thread.Deque;
import sys.thread.Thread;
#end

@:access(lime.media.AudioBuffer)
@:access(openfl.media.SoundChannel)
@:access(flixel.sound.FlxSound)
class AnalysisSource
{
	var source:AudioSource;
	#if (sys && lime_vorbis)
	var queue:Deque<AudioBuffer>;
	#end

	public function new(sound:FlxSound)
	{
		var playing:AudioSource = (sound != null && sound._channel != null) ? sound._channel.__audioSource : null;
		if (playing == null || playing.buffer == null) return;

		if (playing.buffer.data != null)
		{
			source = playing;
			return;
		}

		#if (sys && lime_vorbis)
		var path:String = Std.isOfType(playing.buffer.__srcCustom, String) ? playing.buffer.__srcCustom : null;
		if (path == null) return;

		var result:Deque<AudioBuffer> = queue = new Deque<AudioBuffer>();
		Thread.create(function()
		{
			var buffer:AudioBuffer = null;
			try { buffer = decodeMixed(path); } catch(e:Dynamic) {}
			if (buffer != null) result.add(buffer);
		});
		#end
	}

	public function poll():AudioSource
	{
		#if (sys && lime_vorbis)
		if (source == null && queue != null)
		{
			var buffer:AudioBuffer = queue.pop(false);
			if (buffer != null)
			{
				queue = null;
				source = new AudioSource();
				source.buffer = buffer;
			}
		}
		#end
		return source;
	}

	#if (sys && lime_vorbis)
	static function decodeMixed(path:String):AudioBuffer
	{
		var vorbis:VorbisFile = VorbisFile.fromFile(path);
		if (vorbis == null) return null;

		var info = vorbis.info();
		var channels:Int = info.channels;
		var total:Int = haxe.Int64.toInt(vorbis.pcmTotal());
		var output:Bytes = Bytes.alloc(total * 2);
		var chunk:Bytes = Bytes.alloc(0x1000 * channels * 2);
		var written:Int = 0;

		while (written < total)
		{
			var read:Int = vorbis.read(chunk, 0, chunk.length, false, 2, true);
			if (read == Vorbis.HOLE) continue;
			if (read <= 0) break;

			var frames:Int = Std.int(read / (2 * channels));
			for (i in 0...frames)
			{
				if (written >= total) break;
				var sum:Int = 0;
				for (c in 0...channels)
				{
					var value:Int = chunk.getUInt16((i * channels + c) * 2);
					if (value >= 0x8000) value -= 0x10000;
					sum += value;
				}
				if (sum > 32767) sum = 32767;
				else if (sum < -32768) sum = -32768;
				output.setUInt16(written * 2, sum & 0xFFFF);
				written++;
			}
		}
		vorbis.clear();

		var buffer:AudioBuffer = new AudioBuffer();
		buffer.channels = 1;
		buffer.bitsPerSample = 16;
		buffer.sampleRate = info.rate;
		buffer.data = new UInt8Array(output);
		return buffer;
	}
	#end
}
