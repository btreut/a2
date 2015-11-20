
MODULE OpenALSound; (** AUTHOR "g.f."; PURPOSE "OpenAL sound driver"; *)

IMPORT S := SYSTEM, Modules, SoundDevices, AL := OpenAL, Objects, Files, 
			Strings, Streams, Log := KernelLog;

CONST
		(* States for channel *)
		StatePlaying = 1;
		StatePaused = 3;
		StateStoped = 4;
		StateClosed = 5;



		Debug = TRUE;

		NumBuffers = 20;
		
		OpenALConfig ="openalplay.ini";

TYPE
		Driver = OBJECT(SoundDevices.Driver)
			VAR
				enabled: BOOLEAN;
				playChannel: PlayChannel;
				ctx: AL.ALCcontext;
				dev: AL.ALCdevice;

			PROCEDURE & Initialize;
			BEGIN
				SetName("OpenAL sound driver");
				desc := "Sound driver for UnixAos";
				enabled := FALSE;
				playChannel := NIL
			END Initialize;
			
			PROCEDURE CreateALContext( ): BOOLEAN;
			VAR name: ARRAY 64 OF CHAR; ok: BOOLEAN;
			BEGIN
				GetDeviceName( name );
				dev := AL.alcOpenDevice( name );
				IF dev # 0 THEN
					ctx := AL.alcCreateContext( dev, 0 );
					ok := AL.alcMakeContextCurrent( ctx );
					IF ok THEN  RETURN TRUE  END
				END;
				Log.Enter;  Log.String( "OpenALSound.Driver.CreateALContext:  failed!" );  Log.Exit;
				RETURN FALSE
			END CreateALContext;
			
			PROCEDURE DestroyALContext;
			VAR ignore: BOOLEAN;
			BEGIN
				ignore := AL.alcMakeContextCurrent( 0 );
				AL.alcDestroyContext( ctx );
				ignore := AL.alcCloseDevice( dev );
			END DestroyALContext;

			PROCEDURE Enable*;
			BEGIN
				enabled := TRUE;
				IF playChannel # NIL THEN  playChannel.Start  END;
			END Enable;

			PROCEDURE Disable*;
			BEGIN
				IF playChannel # NIL THEN  playChannel.Pause  END;
				enabled := FALSE
			END Disable;


			PROCEDURE GetNativeFrequency*(nr : LONGINT) : LONGINT;
			BEGIN
				RETURN 48000;
			END GetNativeFrequency;



			PROCEDURE OpenPlayChannel*(	VAR channel: SoundDevices.Channel; 
												samplingRate, samplingResolution: LONGINT;
												nofSubChannels, format : LONGINT; 
											VAR res : LONGINT );
			BEGIN {EXCLUSIVE}
				IF ~enabled  THEN
					Log.Enter;
					Log.String( "OpenALSound.OpenPlayChannel: OpenAL driver is disabled" );  
					Log.Exit;
					res := SoundDevices.ResNoMoreChannels;
					RETURN
				END;
				IF playChannel # NIL THEN
					Log.Enter;
					Log.String( "OpenALSound.OpenPlayChannel: OpenAL driver already in use" );  
					Log.Exit;
					res := SoundDevices.ResNoMoreChannels;
					RETURN
				END;
								
				channel := NIL;

				IF ~((samplingRate > 0) & (samplingRate <= 48000)) THEN
					res := SoundDevices.ResUnsupportedFrequency;
					RETURN
				END;

				(* Check for supported samplingResolution *)
				IF ~(samplingResolution IN {8, 16}) THEN
					res := SoundDevices.ResUnsupportedSamplingRes;
					RETURN
				END;

				(* Check for supported subchannel *)
				IF (nofSubChannels # 1) & (nofSubChannels # 2) THEN
					res := SoundDevices.ResUnsupportedSubChannels;
					RETURN
				END;

				(* Check for supported format *)
				IF format # SoundDevices.FormatPCM THEN
					res := SoundDevices.ResUnsupportedFormat;
					RETURN
				END;

				(* Fine, we passed all tests. Let's create a channel. *)
				IF ~CreateALContext( ) THEN
					res := SoundDevices.ResNoMoreChannels;
					RETURN
				END; 
				
				NEW( playChannel, SELF, samplingRate, samplingResolution, nofSubChannels );
				channel := playChannel;

				IF Debug THEN
					Log.Enter;
					Log.String("OpenALSound.OpenPlayChannel: "); 
					Log.Int(samplingRate, 1); Log.String("Hz, ");
					Log.Int(samplingResolution, 1); Log.String("bit, ");
					Log.Int(nofSubChannels, 1); Log.String(" channel(s)"); 
					Log.Exit
				END;

				res := SoundDevices.ResOK
			END OpenPlayChannel;



			PROCEDURE OpenRecordChannel*(	VAR channel: SoundDevices.Channel; 
													samplingRate, samplingResolution: LONGINT;
													 nofSubChannels, format : LONGINT; 
												VAR res : LONGINT );
			BEGIN {EXCLUSIVE}
				(* not impemented *)
				res := SoundDevices.ResNoMoreChannels;
				channel := NIL
			END OpenRecordChannel;



			PROCEDURE RegisterMixerChangeListener*(mixChangedProc : SoundDevices.MixerChangedProc);
			BEGIN {EXCLUSIVE}
			END RegisterMixerChangeListener;

			PROCEDURE UnregisterMixerChangeListener*(mixChangeProc : SoundDevices.MixerChangedProc);
			BEGIN {EXCLUSIVE}
			END UnregisterMixerChangeListener;

			PROCEDURE GetMixerChannel*(channelNr : LONGINT; VAR channel : SoundDevices.MixerChannel);
			BEGIN
				channel := NIL
			END GetMixerChannel;

			PROCEDURE GetNofMixerChannels*() : LONGINT;
			BEGIN
				RETURN 0
			END GetNofMixerChannels;


		END Driver;



	

		PlayChannel = OBJECT( SoundDevices.Channel );
		VAR  
			source: AL.ALuint;
			buffers: ARRAY NumBuffers OF AL.ALuint;
			freeBuffers: AL.ALint;
			
			bufferListener: SoundDevices.BufferListener;
			
			frequency: AL.ALuint;
			format: AL.ALenum;
			count: LONGINT;
			
			volume: LONGINT;
			state: LONGINT;
			
			driver: Driver;

			PROCEDURE &Initialize*( driver: Driver;  samplingRate, bitsPerSample, nofChannels : LONGINT );
			BEGIN				
				SELF.driver := driver;
				
				AL.alGenBuffers( NumBuffers, ADDRESSOF( buffers[0] ) );
				AL.alGenSources( 1, ADDRESSOF( source ) );
				IF AL.alGetError() # AL.AL_NO_ERROR THEN
					Log.Enter;
					Log.String( "PlayChannel.Initialize: failed to allocat sources" );  
					Log.Exit
				END;
				frequency := samplingRate;
				(* format of wav  *)
				IF nofChannels = 1 THEN
				  	CASE bitsPerSample OF
				  		| 8:  format := AL.AL_FORMAT_MONO8
				  		|16: format := AL.AL_FORMAT_MONO16
				  	ELSE 
				  		format:= AL.AL_FORMAT_MONO8;	
				  	END;
				ELSIF nofChannels = 2 THEN
				  	CASE bitsPerSample OF
				  		| 8:  format := AL.AL_FORMAT_STEREO8
				  		|16: format := AL.AL_FORMAT_STEREO16
				  	ELSE 
				  		format:= AL.AL_FORMAT_STEREO8;	
				  	END;
				ELSE 
					format := AL.AL_FORMAT_MONO8
				END;
				count := 0;  freeBuffers := 0;
				state := StateStoped
			END Initialize;
			

			
			PROCEDURE RegisterBufferListener*( bufferListener : SoundDevices.BufferListener );
			BEGIN 
				SELF.bufferListener := bufferListener
			END RegisterBufferListener;


			PROCEDURE QueueBuffer*( x : SoundDevices.Buffer );
			VAR buffer: AL.ALuint;  alstate: AL.ALint;  
			BEGIN {EXCLUSIVE}
				AWAIT( state = StatePlaying );
				IF count < NumBuffers THEN
					AL.alBufferData( buffers[count], format, ADDRESSOF( x.data[0] ),  x.len, frequency );
					bufferListener( x );
					INC( count );
					IF count = NumBuffers THEN
						AL.alSourceQueueBuffers( source, count, ADDRESSOF( buffers[0] ) );
						AL.alSourcePlay( source );
						IF AL.alGetError() # AL.AL_NO_ERROR THEN
							Log.Enter;
							Log.String( "OpenALSound.PlayChannel.QueueBuffer: start paying failed" ); 
							Log.Exit
						END
					END
				ELSE
					REPEAT
						AL.alGetSourcei( source, AL.AL_BUFFERS_PROCESSED, freeBuffers );
						IF freeBuffers <= 0 THEN  Objects.Sleep( 5 )  END;	
					UNTIL freeBuffers > 0;
					AL.alSourceUnqueueBuffers( source, 1, ADDRESSOF( buffer ) );
					DEC( freeBuffers );
					AL.alBufferData( buffer, format, ADDRESSOF( x.data[0] ),  x.len, frequency );
					bufferListener( x );
					INC( count ); 
					AL.alSourceQueueBuffers( source, 1, ADDRESSOF( buffer ) );
					IF AL.alGetError( ) # AL.AL_NO_ERROR THEN
						Log.Enter;
						Log.String( "OpenALSound.PlayChannel.QueueBuffer: queueing failed" );  Log.Int( count, 5 ); 
						Log.Exit;
						RETURN
					END;
					AL.alGetSourcei( source, AL.AL_SOURCE_STATE, alstate );
					IF alstate # AL.AL_PLAYING THEN
						AL.alSourcePlay( source )
					END;
				END
			END QueueBuffer;
			

			PROCEDURE SetVolume*( vol : LONGINT );
			VAR gain: AL.ALfloat;
			BEGIN
				IF vol < 0 THEN  vol := 0
				ELSIF vol > 255 THEN vol := 255
				END;
				volume := vol;
				gain := volume/255;
				AL.alSourcef(source, AL.AL_GAIN, gain);
			END SetVolume;


			PROCEDURE GetVolume*() : LONGINT;
			BEGIN
				RETURN SELF.volume
			END GetVolume;

			PROCEDURE GetPosition*() : LONGINT;
			BEGIN
				RETURN 0
			END GetPosition;	

			PROCEDURE Start*;
			BEGIN {EXCLUSIVE}
				ASSERT(state # StateClosed);
				state := StatePlaying
			END Start;


			PROCEDURE Pause*;
			BEGIN
				state := StatePaused
			END Pause;

			PROCEDURE Stop*;
			BEGIN
				state := StateStoped;
			END Stop;


			PROCEDURE Close*;
			BEGIN
				Stop;
				AL.alDeleteSources( 1, source );
				AL.alDeleteBuffers( NumBuffers, ADDRESSOF( buffers[0] ) );
				driver.DestroyALContext;
				driver.playChannel := NIL;
				state := StateClosed;
				IF Debug THEN
					Log.Enter;  Log.String( "OpenALSound: play cannel closed" );  Log.Exit
				END
			END Close;
	

		END PlayChannel;




VAR  driver: Driver;

	(* get device name from configuration file *)
	PROCEDURE GetDeviceName( VAR sdev: ARRAY OF CHAR );
	VAR file: Files.File;
		rd: Files.Reader;
		found: BOOLEAN;
	BEGIN
		sdev := ""; 
		file := Files.Old( OpenALConfig );
		IF file = NIL THEN  RETURN  END;
		Files.OpenReader( rd, file, 0 );
		rd.SkipWhitespace( );
		found := FALSE ;
		WHILE  (~found) & (rd.res = Streams.Ok)  DO
			rd.Ln( sdev );
			Strings.Trim(sdev, " ");
			found := sdev[0] # "#";
			rd.SkipWhitespace( );
		END;	
	END GetDeviceName;


	(* Install the driver *)
	PROCEDURE Install*;
	VAR res: LONGINT;
	BEGIN {EXCLUSIVE}
		(* Avoid multiple installation *)
		IF driver = NIL THEN
			NEW( driver );
			SoundDevices.devices.Add( driver, res );
			IF res = 0 THEN
				driver.Enable;
				Log.Enter;  Log.String( "OpenAL sound driver installed" );  Log.Exit
			END
		END;
	END Install;

	(** Enable is a hardware enable. *)
	PROCEDURE Enable*;
	BEGIN
		IF driver # NIL THEN  driver.Enable  END
	END Enable;

	(** Disable is a hardware pause. *)
	PROCEDURE Disable*;
	BEGIN
		IF driver # NIL THEN  driver.Disable  END
	END Disable;

	(** Cleanup function called when the module is unloaded *)
	PROCEDURE Cleanup;
	BEGIN
		Disable;
		IF driver # NIL THEN  
			SoundDevices.devices.Remove( driver );
			driver := NIL;
			Log.Enter;  Log.String( "OpenAL sound driver removed" );  Log.Exit
		END
	END Cleanup;
	

BEGIN
	Modules.InstallTermHandler( Cleanup )
END OpenALSound.


 
 
 
 
 SystemTools.Free MP3Player OpenALSound ~ 
 
 OpenALSound.Install ~

 OpenALSound.Disable ~ 
 OpenALSound.Enable ~

  MP3Player.Open test.mp3 ~
  
  MP3Player.Open sesta.mp3 ~