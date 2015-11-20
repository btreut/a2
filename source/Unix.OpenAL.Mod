MODULE OpenAL; (** AUTHOR "fnecati"; PURPOSE "OpenAL cross platform audio library"; *)

IMPORT
	SYSTEM, Unix, Modules, Strings, KernelLog;

CONST
	libname="libopenal.so";

TYPE
  String256*=ARRAY 256 OF CHAR;
  PString256*= POINTER TO ARRAY OF String256;


  ALbyte    * =  CHAR;  (* 1-byte signed *)
  ALshort   * =  INTEGER;  (* 2-byte signed *)
  ALint     * =  LONGINT;  (* 4-byte signed *)

  ALfloat   * =  REAL;
  ALdouble  * =  LONGREAL;
  ALboolean * =  BOOLEAN;

  ALubyte   * =  CHAR;     (* 1-byte unsigned *)
  ALushort  * =  INTEGER;     (* 2-byte unsigned *)
  ALuint    * =  LONGINT;    (* 4-byte signed *)

  ALsizei   * =  LONGINT;  (* 4-byte signed *)

  ALenum    * =  LONGINT;

  PALboolean * =  ADDRESS; (*   TO ALboolean;*)
  PALfloat   * =  ADDRESS; (*   TO ALfloat;*)
  PALdouble  * =  ADDRESS; (*   TO ALdouble;*)
  PALbyte    * =  ADDRESS; (*   TO ALbyte;*)
  PALshort   * =  ADDRESS; (*   TO ALshort;*)
  PALint     * =  ADDRESS; (*   TO ALint; *)
  PALubyte   * =  ADDRESS; (*   TO ALubyte; *)
  PALushort  * =  ADDRESS; (*   TO ALushort; *)
  PALuint    * =  ADDRESS; (*   TO ALuint; *)

CONST
  AL_INVALID                              * =  (-1);
  AL_NONE                                 * =  0; (* "no distance model" or "no buffer" *)
  AL_FALSE                                * =  0;
  AL_TRUE                                 * =  1;
  AL_SOURCE_ABSOLUTE                      * =  201H;
  AL_SOURCE_RELATIVE                      * =  202H; (** Indicate Source has relative coordinates. *)
 (**
 * Directional source, inner cone angle, in degrees.
 * Range:    [0-360]
 * Default:  360
 *)
  AL_CONE_INNER_ANGLE                     * =  1001H;

(**
 * Directional source, outer cone angle, in degrees.
 * Range:    [0-360]
 * Default:  360
 *)
  AL_CONE_OUTER_ANGLE                     * =  1002H;

  (**
 * Specify the pitch to be applied, either at source,
 *  or on mixer results, at listener.
 * Range:   [0.5-2.0]
 * Default: 1.0
 *)
  AL_PITCH                                * =  1003H;

  (**
 * Specify the current location in three dimensional space.
 * OpenAL, like OpenGL, uses a right handed coordinate system,
 *  where in a frontal default view X (thumb) points right,
 *  Y points up (index finger), and Z points towards the
 *  viewer/camera (middle finger).
 * To switch from a left handed coordinate system, flip the
 *  sign on the Z coordinate.
 * Listener position is always in the world coordinate system.
 *)
  AL_POSITION                             * =  1004H;

  AL_DIRECTION                            * =  1005H; (** Specify the current direction. *)
  AL_VELOCITY                             * =  1006H; (** Specify the current velocity in three dimensional space. *)

  (**
 * Indicate whether source is looping.
 * Type: ALboolean?
 * Range:   [AL_TRUE, AL_FALSE]
 * Default: FALSE.
 *)
  AL_LOOPING                              * =  1007H;

  (**
 * Indicate the buffer to provide sound samples.
 * Type: ALuint.
 * Range: any valid Buffer id.
 *)
  AL_BUFFER                               * =  1009H;

  (**
 * Indicate the gain (volume amplification) applied.
 * Type:   ALfloat.
 * Range:  ]0.0-  ]
 * A value of 1.0 means un-attenuated/unchanged.
 * Each division by 2 equals an attenuation of -6dB.
 * Each multiplicaton with 2 equals an amplification of +6dB.
 * A value of 0.0 is meaningless with respect to a logarithmic
 *  scale; it is interpreted as zero volume - the channel
 *  is effectively disabled.
 *)
  AL_GAIN                                 * =  100AH;

  (*
 * Indicate minimum source attenuation
 * Type: ALfloat
 * Range:  [0.0 - 1.0]
 *
 * Logarthmic
 *)
  AL_MIN_GAIN                             * =  100DH;

 (**
 * Indicate maximum source attenuation
 * Type: ALfloat
 * Range:  [0.0 - 1.0]
 *
 * Logarthmic
 *)
  AL_MAX_GAIN                             * =  100EH;

  (**  Indicate listener orientation.  at/up  *)
  AL_ORIENTATION                          * =  100FH;


(*   AL_CHANNEL_MASK                         * =  3000H; *)

  (**  Source state information. *)
  AL_SOURCE_STATE                         * =  1010H;
  AL_INITIAL                              * =  1011H;
  AL_PLAYING                              * =  1012H;
  AL_PAUSED                               * =  1013H;
  AL_STOPPED                              * =  1014H;

  (**  Buffer Queue params *)
  AL_BUFFERS_QUEUED                       * =  1015H;
  AL_BUFFERS_PROCESSED                    * =  1016H;

 (**  Source buffer position information *)
  AL_SEC_OFFSET                   * = 1024H;
  AL_SAMPLE_OFFSET                * = 1025H;
  AL_BYTE_OFFSET                  * = 1026H;

(*
 * Source type (Static, Streaming or undetermined)
 * Source is Static if a Buffer has been attached using AL_BUFFER
 * Source is Streaming if one or more Buffers have been attached using alSourceQueueBuffers
 * Source is undetermined when it has the NULL buffer attached
 *)
  AL_SOURCE_TYPE                   * = 1027H;
  AL_STATIC                        * = 1028H;
  AL_STREAMING                     * = 1029H;
  AL_UNDETERMINED                  * = 1030H;

(** Sound samples: format specifier. *)
  AL_FORMAT_MONO8                         * =  1100H;
  AL_FORMAT_MONO16                        * =  1101H;
  AL_FORMAT_STEREO8                       * =  1102H;
  AL_FORMAT_STEREO16                      * =  1103H;

(**
 * source specific reference distance
 * Type: ALfloat
 * Range:  0.0 - +inf
 *
 * At 0.0, no distance attenuation occurs.  Default is
 * 1.0.
 *)
  AL_REFERENCE_DISTANCE            * = 1020H;

(**
 * source specific rolloff factor
 * Type: ALfloat
 * Range:  0.0 - +inf
 *
 *)
  AL_ROLLOFF_FACTOR                * = 1021H;

(**
 * Directional source, outer cone gain.
 *
 * Default:  0.0
 * Range:    [0.0 - 1.0]
 * Logarithmic
 *)
  AL_CONE_OUTER_GAIN               * = 1022H;

(**
 * Indicate distance above which sources are not
 * attenuated using the inverse clamped distance model.
 *
 * Default: +inf
 * Type: ALfloat
 * Range:  0.0 - +inf
 *)
  AL_MAX_DISTANCE                  * = 1023H;

(**
 * Sound samples: frequency, in units of Hertz [Hz].
 * This is the number of samples per second. Half of the
 *  sample frequency marks the maximum significant
 *  frequency component.
 *)

  AL_FREQUENCY                            * =  2001H;
  AL_BITS                                 * =  2002H;
  AL_CHANNELS                             * =  2003H;
  AL_SIZE                                 * =  2004H;
 (* AL_DATA                                 * =  2005H;*)
(**
 * Buffer state.
 *
 * Not supported for public use (yet).
 *)

  AL_UNUSED                               * =  2010H;
  AL_PENDING                              * =  2011H;
  AL_PROCESSED                            * =  2012H;

(** Errors: No Error. *)
  AL_NO_ERROR                             * =  AL_FALSE;

  AL_INVALID_NAME                         * =  0A001H; (**  Invalid Name paramater passed to AL call. *)
  AL_INVALID_ENUM                         * =  0A002H; (**  Invalid parameter passed to AL call. *)
  AL_INVALID_VALUE                        * =  0A003H; (**  Invalid enum parameter value. *)
  AL_INVALID_OPERATION                    * =  0A004H; (**  Illegal call. *)
  AL_OUT_OF_MEMORY                        * =  0A005H;

(** Context strings: Vendor Name. *)
  AL_VENDOR                               * =  0B001H;
  AL_VERSION                              * =  0B002H;
  AL_RENDERER                             * =  0B003H;
  AL_EXTENSIONS                           * =  0B004H;

  AL_DOPPLER_FACTOR                       * =  0C000H; (** Doppler scale.  Default 1.0 *)
  AL_DOPPLER_VELOCITY                     * =  0C001H; (** Tweaks speed of propagation. *)
  AL_SPEED_OF_SOUND                * = 0C003H;   (** Speed of Sound in units per second *)

(**
 * Distance models
 *
 * used in conjunction with DistanceModel
 *
 * implicit: NONE, which disances distance attenuation.
 *)
  AL_DISTANCE_MODEL                       * =  0D000H;
  AL_INVERSE_DISTANCE                     * =  0D001H;
  AL_INVERSE_DISTANCE_CLAMPED             * =  0D002H;
  AL_LINEAR_DISTANCE               * = 0D003H;
  AL_LINEAR_DISTANCE_CLAMPED       * = 0D004H;
  AL_EXPONENT_DISTANCE             * = 0D005H;
  AL_EXPONENT_DISTANCE_CLAMPED     * = 0D006H;
(* **************** *)
(* **************** *)

(* AL Context API types *)

TYPE
  ALCbyte    * =  CHAR; (* 1-byte signed *)
  ALCshort   * =  INTEGER;  (* 2-byte signed *)
  ALCint     * =  LONGINT;  (* 4-byte signed *)

  ALCfloat   * =  REAL;
  ALCdouble  * =  LONGREAL;
  ALCboolean * =  BOOLEAN;

  ALCubyte   * =  CHAR;     (* 1-byte unsigned *)
  ALCushort  * =  INTEGER;     (* 2-byte unsigned *)
  ALCuint    * =  LONGINT;    (* 4-byte signed *)

  ALCsizei   * =  LONGINT;  (* 4-byte signed *)

  ALCenum    * =  LONGINT;

  ALCcontext * =  ADDRESS;
  ALCdevice  * =  ADDRESS;

  PALCboolean * =  ADDRESS; (*   TO ALCBoolean; *)
  PALCfloat   * =  ADDRESS; (*   TO ALCfloat; *)
  PALCdouble  * =  ADDRESS; (*   TO ALCDouble; *)
  PALCbyte    * =  ADDRESS; (*   TO ALCbyte; *)
  PALCshort   * =  ADDRESS; (*   TO ALCshort; *)
  PALCint     * =  ADDRESS; (*   TO ALCint; *)
  PALCubyte   * =  ADDRESS; (*   TO ALCubyte; *)
  PALCushort  * =  ADDRESS; (*   TO ALCushort; *)
  PALCuint    * =  ADDRESS; (*   TO ALCuint; *)

CONST
  ALC_INVALID                             * =  (-1);
  ALC_FALSE                               * =  AL_FALSE;
  ALC_TRUE                                * =  AL_TRUE;

(** The Specifier string for default device *)
  ALC_MAJOR_VERSION                       * =  1000H;
  ALC_MINOR_VERSION                       * =  1001H;
  ALC_ATTRIBUTES_SIZE                     * =  1002H;
  ALC_ALL_ATTRIBUTES                      * =  1003H;
  ALC_DEFAULT_DEVICE_SPECIFIER            * =  1004H;
  ALC_DEVICE_SPECIFIER                    * =  1005H;
  ALC_EXTENSIONS                          * =  1006H;


 (** Capture extension *)
  ALC_CAPTURE_DEVICE_SPECIFIER     * = 310H;
  ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER * = 311H;
  ALC_CAPTURE_SAMPLES              * = 312H;

  ALC_FREQUENCY                           * =  1007H;  (* followed by <int> Hz *)
  ALC_REFRESH                             * =  1008H; (* followed by <int> Hz *)
  ALC_SYNC                                * =  1009H; (* followed by AL_TRUE, AL_FALSE *)
  ALC_MONO_SOURCES                 * = 1010H; (*  followed by <int> Num of requested Mono (3D) Sources *)
  ALC_STEREO_SOURCES               * = 1011H; (* followed by <int> Num of requested Stereo Sources *)

 (** errors *)
   ALC_NO_ERROR                            * =  ALC_FALSE;
  ALC_INVALID_DEVICE                      * =  0A001H;
  ALC_INVALID_CONTEXT                     * =  0A002H;
  ALC_INVALID_ENUM                        * =  0A003H;
  ALC_INVALID_VALUE       * =  0A004H;
  ALC_OUT_OF_MEMORY                       * =  0A005H;


(*!************ alext.h *********)
(****************************)

  AL_FORMAT_IMA_ADPCM_MONO16_EXT           * =10000H;
  AL_FORMAT_IMA_ADPCM_STEREO16_EXT         * =10001H;
  AL_FORMAT_WAVE_EXT                       * =10002H;

  AL_FORMAT_VORBIS_EXT                     * =10003H;


  AL_FORMAT_QUAD8_LOKI                     * =10004H;
  AL_FORMAT_QUAD16_LOKI                    * =10005H;


  AL_FORMAT_MONO_FLOAT32                   * =10010H;
  AL_FORMAT_STEREO_FLOAT32                 * =10011H;

  AL_FORMAT_MONO_DOUBLE_EXT                * =10012H;
  AL_FORMAT_STEREO_DOUBLE_EXT              * =10013H;

  ALC_CHAN_MAIN_LOKI                       * =500001H;
  ALC_CHAN_PCM_LOKI                        * =500002H;
  ALC_CHAN_CD_LOKI                         * =500003H;

  ALC_DEFAULT_ALL_DEVICES_SPECIFIER        * =1012H;
  ALC_ALL_DEVICES_SPECIFIER                * =1013H;

  AL_FORMAT_QUAD8                          * =1204H;
  AL_FORMAT_QUAD16                         * =1205H;
  AL_FORMAT_QUAD32                         * =1206H;
  AL_FORMAT_REAR8                          * =1207H;
  AL_FORMAT_REAR16                         * =1208H;
  AL_FORMAT_REAR32                         * =1209H;
  AL_FORMAT_51CHN8                         * =120AH;
  AL_FORMAT_51CHN16                        * =120BH;
  AL_FORMAT_51CHN32                        * =120CH;
  AL_FORMAT_61CHN8                         * =120DH;
  AL_FORMAT_61CHN16                        * =120EH;
  AL_FORMAT_61CHN32                        * =120FH;
  AL_FORMAT_71CHN8                         * =1210H;
  AL_FORMAT_71CHN16                        * =1211H;
  AL_FORMAT_71CHN32                        * =1212H;

  AL_FORMAT_MONO_MULAW                     * =10014H;
  AL_FORMAT_STEREO_MULAW                   * =10015H;
  AL_FORMAT_QUAD_MULAW                     * =10021H;
  AL_FORMAT_REAR_MULAW                     * =10022H;
  AL_FORMAT_51CHN_MULAW                    * =10023H;
  AL_FORMAT_61CHN_MULAW                    * =10024H;
  AL_FORMAT_71CHN_MULAW                    * =10025H;

  AL_FORMAT_MONO_IMA4                      * =1300H;
  AL_FORMAT_STEREO_IMA4                    * =1301H;

  ALC_CONNECTED                            * =313H;

  AL_SOURCE_DISTANCE_MODEL*               =  200H;

  AL_BYTE_RW_OFFSETS_SOFT*             = 1031H;
  AL_SAMPLE_RW_OFFSETS_SOFT*           = 1032H;

  AL_LOOP_POINTS_SOFT                * =     2015H;



VAR

  oallib: LONGINT;

(* Renderer State management *)
alEnable-: PROCEDURE { C } (capability : ALenum);
alDisable -: PROCEDURE { C } (capability : ALenum);
alIsEnabled-: PROCEDURE { C } (capability : ALenum) : ALboolean;
(* alHint-: PROCEDURE { C } (target, mode : ALenum); *)

(* State retrieval *)
alGetBoolean- : PROCEDURE { C } (param : ALenum) : ALboolean;
alGetInteger-: PROCEDURE { C } (param : ALenum) : ALint;
alGetFloat-: PROCEDURE { C } (param : ALenum) : ALfloat;
alGetDouble-: PROCEDURE { C } (param : ALenum) : ALdouble;
alGetBooleanv-: PROCEDURE { C } (param : ALenum; VAR data : ALboolean);
alGetIntegerv-: PROCEDURE { C } (param : ALenum; VAR data : ALint);
alGetFloatv-: PROCEDURE { C } (param : ALenum;  VAR data : ALfloat);
alGetDoublev-: PROCEDURE { C } (param : ALenum; VAR data : ALdouble);
alGetString-: PROCEDURE { C } (param : ALenum) : PALubyte;
(*
 * Error support.
 * Obtain the most recent error generated in the AL state machine.
 *)
alGetError-: PROCEDURE { C } () : ALenum;

(*
 * Extension support.
 * Query for the presence of an extension, and obtain any appropriate
 * function pointers and enum values.
 *)
alIsExtensionPresent-: PROCEDURE { C } (CONST fname : ARRAY OF CHAR) : ALboolean;
alGetProcAddress-: PROCEDURE { C } (CONST fname : ARRAY OF CHAR): ADDRESS;
alGetEnumValue-: PROCEDURE { C } (VAR ename : ALubyte) : ALenum;

 (*  LISTENER
  Listener represents the location and orientation of the
  'user' in 3D-space.

  Properties include: -

  Gain         AL_GAIN         ALfloat
  Position     AL_POSITION     ALfloat[3]
  Velocity     AL_VELOCITY     ALfloat[3]
  Orientation  AL_ORIENTATION  ALfloat[6] (Forward then Up vectors)
*)

(* Set Listener parameters *)
alListenerf-: PROCEDURE { C } (param : ALenum; value : ALfloat);
alListener3f-: PROCEDURE { C } (param : ALenum; v1, v2, v3 : ALfloat);
alListenerfv-: PROCEDURE { C } (param : ALenum;  values : PALfloat);
alListeneri-: PROCEDURE { C } (param : ALenum; value : ALint);
alListener3i-: PROCEDURE { C } (param : ALenum; v1, v2, v3 : ALint);
alListeneriv-: PROCEDURE { C } (param : ALenum;  values : PALint);

(* Get Listener parameters *)
alGetListenerf-: PROCEDURE { C } (param : ALenum; VAR value : ALfloat);
alGetListener3f-: PROCEDURE { C } (param : ALenum; VAR v1, v2,  v3 : ALfloat);
alGetListenerfv-: PROCEDURE { C } (param : ALenum; values : PALfloat);
alGetListeneri-: PROCEDURE { C } (param : ALenum; VAR value : ALint);
alGetListener3i-: PROCEDURE { C } (param : ALenum; VAR v1, v2, v3:  ALint);
alGetListeneriv-: PROCEDURE { C } (param : ALenum; values : PALint);

(*
  SOURCE
  Sources represent individual sound objects in 3D-space.
  Sources take the PCM data provided in the specified Buffer,
  apply Source-specific modifications, and then
  submit them to be mixed according to spatial arrangement etc.

  Properties include: -

  Gain                              AL_GAIN                 ALfloat
  Min Gain                          AL_MIN_GAIN             ALfloat
  Max Gain                          AL_MAX_GAIN             ALfloat
  Position                          AL_POSITION             ALfloat[3]
  Velocity                          AL_VELOCITY             ALfloat[3]
  Direction                         AL_DIRECTION            ALfloat[3]
  Head Relative Mode                AL_SOURCE_RELATIVE      ALint (AL_TRUE or AL_FALSE)
  Reference Distance                AL_REFERENCE_DISTANCE   ALfloat
  Max Distance                      AL_MAX_DISTANCE         ALfloat
  RollOff Factor                    AL_ROLLOFF_FACTOR       ALfloat
  Inner Angle                       AL_CONE_INNER_ANGLE     ALint or ALfloat
  Outer Angle                       AL_CONE_OUTER_ANGLE     ALint or ALfloat
  Cone Outer Gain                   AL_CONE_OUTER_GAIN      ALint or ALfloat
  Pitch                             AL_PITCH                ALfloat
  Looping                           AL_LOOPING              ALint (AL_TRUE or AL_FALSE)
  MS Offset                         AL_MSEC_OFFSET          ALint or ALfloat
  Byte Offset                       AL_BYTE_OFFSET          ALint or ALfloat
  Sample Offset                     AL_SAMPLE_OFFSET        ALint or ALfloat
  Attached Buffer                   AL_BUFFER               ALint
  State (Query only)                AL_SOURCE_STATE         ALint
  Buffers Queued (Query only)       AL_BUFFERS_QUEUED       ALint
  Buffers Processed (Query only)    AL_BUFFERS_PROCESSED    ALint
 *)


(* Create Source objects *)
alGenSources-: PROCEDURE { C } (n : ALsizei;  sources : PALuint);

(* Delete Source objects *)
alDeleteSources-: PROCEDURE { C } (n : ALsizei; sources : PALuint);

(* Verify a handle is a valid Source *)
alIsSource-: PROCEDURE { C } (id : ALuint) : ALboolean;

(* Set Source parameters *)
alSourcef-: PROCEDURE { C } (source : ALuint; param : ALenum; value : ALfloat);
alSource3f-: PROCEDURE { C } (source : ALuint; param : ALenum; v1, v2, v3 : ALfloat);
alSourcefv-: PROCEDURE { C } (source : ALuint; param : ALenum; values : PALfloat);
alSourcei-: PROCEDURE { C } (source : ALuint; param : ALenum; value : ALint);
alSource3i-: PROCEDURE { C } (source : ALuint; param : ALenum; v1, v2, v3 : ALint);
alSourceiv-: PROCEDURE { C } (source : ALuint; param : ALenum; values : PALint);

(* Get Source parameters *)
alGetSourcef-: PROCEDURE { C } (source : ALuint; param : ALenum; VAR value : ALfloat);
alGetSource3f-: PROCEDURE { C } (source : ALuint; param : ALenum; VAR v1, v2, v3 : ALfloat);
alGetSourcefv-: PROCEDURE { C } (source : ALuint; param : ALenum; values : PALfloat);
alGetSourcei-: PROCEDURE { C } (source : ALuint; param : ALenum; VAR value : ALint);
alGetSource3i-: PROCEDURE { C } (source : ALuint; param : ALenum; VAR v1, v2, v3 : ALint);
alGetSourceiv-: PROCEDURE { C } (source : ALuint; param : ALenum; values : PALint);

(* Source vector based playback calls *)

(* Play, replay, or resume (if paused) a list of Sources *)
alSourcePlayv-: PROCEDURE { C } (n : ALsizei; sources : PALuint);

(* Pause a list of Sources *)
alSourcePausev-: PROCEDURE { C } (n : ALsizei;  sources : PALuint);
(* Stop a list of Sources *)
alSourceStopv-: PROCEDURE { C } (n : ALsizei;  sources : PALuint);
(* Rewind a list of Sources *)
alSourceRewindv-: PROCEDURE { C } (n : ALsizei;  sources : PALuint);

(* Source based playback calls *)
(* Play, replay, or resume a Source *)
alSourcePlay-: PROCEDURE { C } ( source : ALuint);
(* Pause a Source *)
alSourcePause-: PROCEDURE { C } ( source : ALuint);
(* Stop a Source *)
alSourceStop-: PROCEDURE { C } (source : ALuint);
(* Rewind a Source (set playback postiton to beginning)  *)
alSourceRewind-: PROCEDURE { C }  (source : ALuint);

(*  Source Queuing  *)
alSourceQueueBuffers-: PROCEDURE { C } (source : ALuint; n : ALsizei; buffers : PALuint);
alSourceUnqueueBuffers-: PROCEDURE { C } (source : ALuint; n : ALsizei; buffers : PALuint);

(*
  BUFFER
  Buffer objects are storage space for sample data.
  Buffers are referred to by Sources. One Buffer can be used
  by multiple Sources.

  Properties include: -

  Frequency (Query only)    AL_FREQUENCY      ALint
  Size (Query only)         AL_SIZE           ALint
  Bits (Query only)         AL_BITS           ALint
  Channels (Query only)     AL_CHANNELS       ALint
 *)

(* Create Buffer objects *)
alGenBuffers-: PROCEDURE { C } (n : ALsizei;  buffers : PALuint);
(* Delete Buffer objects *)
alDeleteBuffers-: PROCEDURE { C } (n : ALsizei;  buffers : PALuint);
(* Verify a handle is a valid Buffer *)
alIsBuffer-: PROCEDURE { C } (buffer : ALuint) : ALboolean;
(* Specify the data to be copied into a buffer *)
alBufferData-: PROCEDURE { C } (buffer : ALuint; format : ALenum;  data: ADDRESS ;  size, freq : ALsizei);

(* Set Buffer parameters *)
alBufferf-: PROCEDURE { C } (buffer : ALuint; param : ALenum; value : ALfloat);
alBuffer3f-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  v1, v2, v3: ALfloat);
alBufferfv-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  value : PALfloat);
alBufferi-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  value : ALint);
alBuffer3i-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  v1, v2, v3 : ALint);
alBufferiv-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  value : PALint);

(* Get Buffer parameters *)
alGetBufferf-: PROCEDURE { C } (buffer : ALuint; param : ALenum; VAR value : ALfloat);
alGetBuffer3f-: PROCEDURE { C } (buffer : ALuint; param : ALenum; VAR v1, v2, v3: ALfloat);
alGetBufferfv-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  value : PALfloat);
alGetBufferi-: PROCEDURE { C } (buffer : ALuint; param : ALenum; VAR value : ALint);
alGetBuffer3i-: PROCEDURE { C } (buffer : ALuint; param : ALenum; VAR v1, v2, v3 : ALint);
alGetBufferiv-: PROCEDURE { C } (buffer : ALuint; param : ALenum;  value : PALint);

(* Global Parameters *)
alDistanceModel-: PROCEDURE { C } (value : ALenum);
alDopplerFactor-: PROCEDURE { C } (value : ALfloat);
alSpeedOfSound-: PROCEDURE { C } (value : ALfloat);
alDopplerVelocity-: PROCEDURE { C } (value : ALfloat);




(* Device Management *)
(*! alcOpenDevice-: PROCEDURE { C } (CONST deviceName : ARRAY OF CHAR) : ALCdevice; *)
alcOpenDeviceXXX-: PROCEDURE { C } (deviceName : ADDRESS) : ALCdevice;

alcCloseDevice-: PROCEDURE { C } (device : ALCdevice): ALCboolean;
(* Context Management *)
alcCreateContext-: PROCEDURE { C } (device : ALCdevice; attrList : PALCint) : ALCcontext;
alcMakeContextCurrent-: PROCEDURE { C } ( context : ALCcontext) : ALCboolean;
alcProcessContext-: PROCEDURE { C } (context : ALCcontext);
alcGetCurrentContext-: PROCEDURE { C } () : ALCcontext;
alcGetContextsDevice-: PROCEDURE { C } (context : ALCcontext) : ALCdevice;
alcSuspendContext-: PROCEDURE { C } (context : ALCcontext);
alcDestroyContext-: PROCEDURE { C } (context : ALCcontext);


 (* Error support.
 * Obtain the most recent Context error
 *)
alcGetError-: PROCEDURE { C } (device : ALCdevice) : ALCenum;


(*
 * Extension support.
 * Query for the presence of an extension, and obtain any appropriate
 * function pointers and enum values.
 *)
(*! alcIsExtensionPresent- : PROCEDURE { C } (device : ALCdevice; CONST extName : ARRAY OF CHAR) : ALCboolean; *)
alcIsExtensionPresentXXX- : PROCEDURE { C } (device : ALCdevice; extName : ADDRESS) : ALCboolean;

(*! alcGetProcAddress-: PROCEDURE { C } (device : ALCdevice; CONST funcName:  ARRAY OF CHAR): ADDRESS; *)
alcGetProcAddressXXX-: PROCEDURE { C } (device : ALCdevice; funcName:  ADDRESS): ADDRESS;

alcGetEnumValue-: PROCEDURE { C } (device : ALCdevice; VAR enumName : ALCubyte) : ALCenum;




(* Query functions *)
alcGetString-: PROCEDURE { C } (device : ALCdevice; param : ALCenum) : LONGINT;
alcGetIntegerv -: PROCEDURE { C } ( device : ALCdevice; param : ALCenum; size : ALCsizei;  data : PALCint);

(* Capture functions *)
(*! alcCaptureOpenDevice-:  PROCEDURE { C } (CONST devicename: ARRAY OF CHAR; frequency: ALCuint; format: ALCenum; buffersize: ALCsizei): ALCdevice; *)
alcCaptureOpenDeviceXXX-:  PROCEDURE { C } (devicename: ADDRESS; 
										frequency: ALCuint; format: ALCenum; buffersize: ALCsizei): ALCdevice; 



alcCaptureCloseDevice-: PROCEDURE { C } (device: ALCdevice): ALCboolean;
alcCaptureStart-:  PROCEDURE { C } (device: ALCdevice);
alcCaptureStop-: PROCEDURE { C } (device: ALCdevice);
alcCaptureSamples-: PROCEDURE { C } (device: ALCdevice; buffer: ADDRESS; samples: ALCsizei);

(*
(* extensions *)
alBufferDataStatic-: PROCEDURE { C } (buffer: ALint; format: ALenum; data: ADDRESS; lenx: ALsizei;  freq: ALsizei);
alcSetThreadContext-: PROCEDURE { C }(context: ALCcontext ): ALCboolean;
alcGetThreadContext-: PROCEDURE { C } (): ALCcontext;
alBufferSubDataSOFT-: PROCEDURE { C } (buffer: ALuint; format: ALenum; data: ADDRESS; offset: ALsizei; lengthx: ALsizei);
*)

PROCEDURE LoadFunctions;
BEGIN
		oallib := Unix.Dlopen(libname, 2 );
		ASSERT(oallib # 0, 103);

		Unix.Dlsym( oallib, "alEnable", ADDRESSOF( alEnable));
		Unix.Dlsym( oallib, "alDisable", ADDRESSOF( alDisable));
		Unix.Dlsym( oallib, "alIsEnabled", ADDRESSOF( alIsEnabled));
		Unix.Dlsym( oallib, "alGetBoolean", ADDRESSOF( alGetBoolean));
		Unix.Dlsym( oallib, "alGetInteger", ADDRESSOF( alGetInteger));
		Unix.Dlsym( oallib, "alGetFloat", ADDRESSOF( alGetFloat));
		Unix.Dlsym( oallib, "alGetDouble", ADDRESSOF( alGetDouble));
		Unix.Dlsym( oallib, "alGetBooleanv", ADDRESSOF( alGetBooleanv));
		Unix.Dlsym( oallib, "alGetIntegerv", ADDRESSOF( alGetIntegerv));
		Unix.Dlsym( oallib, "alGetFloatv", ADDRESSOF( alGetFloatv));
		Unix.Dlsym( oallib, "alGetDoublev", ADDRESSOF( alGetDoublev));
		Unix.Dlsym( oallib, "alGetString", ADDRESSOF( alGetString));
		Unix.Dlsym( oallib, "alGetError", ADDRESSOF( alGetError));
		Unix.Dlsym( oallib, "alIsExtensionPresent", ADDRESSOF( alIsExtensionPresent));
		Unix.Dlsym( oallib, "alGetProcAddress", ADDRESSOF( alGetProcAddress));
		Unix.Dlsym( oallib, "alGetEnumValue", ADDRESSOF( alGetEnumValue));

		Unix.Dlsym( oallib, "alListenerf", ADDRESSOF( alListenerf));
		Unix.Dlsym( oallib, "alListener3f", ADDRESSOF( alListener3f));
		Unix.Dlsym( oallib, "alListenerfv", ADDRESSOF( alListenerfv));
		Unix.Dlsym( oallib, "alListeneri", ADDRESSOF( alListeneri));
		Unix.Dlsym( oallib, "alListener3i", ADDRESSOF( alListener3i));
		Unix.Dlsym( oallib, "alListeneriv", ADDRESSOF( alListeneriv));

		Unix.Dlsym( oallib, "alGetListenerf", ADDRESSOF( alGetListenerf));
		Unix.Dlsym( oallib, "alGetListener3f", ADDRESSOF( alGetListener3f));
		Unix.Dlsym( oallib, "alGetListenerfv", ADDRESSOF( alGetListenerfv));
		Unix.Dlsym( oallib, "alGetListeneri", ADDRESSOF( alGetListeneri));
		Unix.Dlsym( oallib, "alGetListener3i", ADDRESSOF( alGetListener3i));
		Unix.Dlsym( oallib, "alGetListeneriv", ADDRESSOF( alGetListeneriv));

		Unix.Dlsym( oallib, "alGenSources", ADDRESSOF( alGenSources));
		Unix.Dlsym( oallib, "alDeleteSources", ADDRESSOF( alDeleteSources));
		Unix.Dlsym( oallib, "alIsSource", ADDRESSOF( alIsSource));
		Unix.Dlsym( oallib, "alSourcei", ADDRESSOF( alSourcei));

		Unix.Dlsym( oallib, "alSourcef", ADDRESSOF( alSourcef));
		Unix.Dlsym( oallib, "alSource3f", ADDRESSOF( alSource3f));
		Unix.Dlsym( oallib, "alSourcefv", ADDRESSOF( alSourcefv));
		Unix.Dlsym( oallib, "alSourcei", ADDRESSOF( alSourcei));
		Unix.Dlsym( oallib, "alSource3i", ADDRESSOF( alSource3i));
		Unix.Dlsym( oallib, "alSourceiv", ADDRESSOF( alSourceiv));

		Unix.Dlsym( oallib, "alGetSourcef", ADDRESSOF( alGetSourcef));
		Unix.Dlsym( oallib, "alGetSource3f", ADDRESSOF( alGetSource3f));
		Unix.Dlsym( oallib, "alGetSourcefv", ADDRESSOF( alGetSourcefv));
		Unix.Dlsym( oallib, "alGetSourcei", ADDRESSOF( alGetSourcei));
		Unix.Dlsym( oallib, "alGetSource3i", ADDRESSOF( alGetSource3i));
		Unix.Dlsym( oallib, "alGetSourceiv", ADDRESSOF( alGetSourceiv));

		Unix.Dlsym( oallib, "alSourcePlayv", ADDRESSOF( alSourcePlayv));
		Unix.Dlsym( oallib, "alSourcePausev", ADDRESSOF( alSourcePausev));
		Unix.Dlsym( oallib, "alSourceStopv", ADDRESSOF( alSourceStopv));
		Unix.Dlsym( oallib, "alSourceRewindv", ADDRESSOF( alSourceRewindv));
		Unix.Dlsym( oallib, "alSourcePlay", ADDRESSOF( alSourcePlay));
		Unix.Dlsym( oallib, "alSourcePause", ADDRESSOF( alSourcePause));
		Unix.Dlsym( oallib, "alSourceStop", ADDRESSOF( alSourceStop));
		Unix.Dlsym( oallib, "alSourceRewind", ADDRESSOF( alSourceRewind));

		Unix.Dlsym( oallib, "alGenBuffers", ADDRESSOF( alGenBuffers));
		Unix.Dlsym( oallib, "alDeleteBuffers", ADDRESSOF( alDeleteBuffers));
		Unix.Dlsym( oallib, "alIsBuffer", ADDRESSOF( alIsBuffer));
		Unix.Dlsym( oallib, "alBufferData", ADDRESSOF( alBufferData));

		Unix.Dlsym( oallib, "alBufferf", ADDRESSOF( alBufferf));
		Unix.Dlsym( oallib, "alBuffer3f", ADDRESSOF( alBuffer3f));
		Unix.Dlsym( oallib, "alBufferfv", ADDRESSOF( alBufferfv));
		Unix.Dlsym( oallib, "alBufferi", ADDRESSOF( alBufferi));
		Unix.Dlsym( oallib, "alBuffer3i", ADDRESSOF( alBuffer3i));
		Unix.Dlsym( oallib, "alBufferiv", ADDRESSOF( alBufferiv));

		Unix.Dlsym( oallib, "alGetBufferf", ADDRESSOF( alGetBufferf));
		Unix.Dlsym( oallib, "alGetBuffer3f", ADDRESSOF( alGetBuffer3f));
		Unix.Dlsym( oallib, "alGetBufferfv", ADDRESSOF( alGetBufferfv));
		Unix.Dlsym( oallib, "alGetBufferi", ADDRESSOF( alGetBufferi));
		Unix.Dlsym( oallib, "alGetBuffer3i", ADDRESSOF( alGetBuffer3i));
		Unix.Dlsym( oallib, "alGetBufferiv", ADDRESSOF( alGetBufferiv));

		Unix.Dlsym( oallib, "alSourceQueueBuffers", ADDRESSOF( alSourceQueueBuffers));
		Unix.Dlsym( oallib, "alSourceUnqueueBuffers", ADDRESSOF( alSourceUnqueueBuffers));
		Unix.Dlsym( oallib, "alDistanceModel", ADDRESSOF( alDistanceModel));
		Unix.Dlsym( oallib, "alDopplerFactor", ADDRESSOF( alDopplerFactor));
		Unix.Dlsym( oallib, "alSpeedOfSound", ADDRESSOF( alSpeedOfSound));
		Unix.Dlsym( oallib, "alDopplerVelocity", ADDRESSOF( alDopplerVelocity));


		Unix.Dlsym( oallib, "alcOpenDevice", ADDRESSOF( alcOpenDeviceXXX));
		Unix.Dlsym( oallib, "alcCloseDevice", ADDRESSOF( alcCloseDevice));
		Unix.Dlsym( oallib, "alcCreateContext", ADDRESSOF( alcCreateContext));
		Unix.Dlsym( oallib, "alcMakeContextCurrent", ADDRESSOF( alcMakeContextCurrent));
		Unix.Dlsym( oallib, "alcProcessContext", ADDRESSOF( alcProcessContext));
		Unix.Dlsym( oallib, "alcGetCurrentContext", ADDRESSOF( alcGetCurrentContext));
		Unix.Dlsym( oallib, "alcGetContextsDevice", ADDRESSOF( alcGetContextsDevice));
		Unix.Dlsym( oallib, "alcSuspendContext", ADDRESSOF( alcSuspendContext));
		Unix.Dlsym( oallib, "alcDestroyContext", ADDRESSOF( alcDestroyContext));
		Unix.Dlsym( oallib, "alcGetError", ADDRESSOF( alcGetError));
		Unix.Dlsym( oallib, "alcGetString", ADDRESSOF( alcGetString));
		Unix.Dlsym( oallib, "alcGetIntegerv", ADDRESSOF( alcGetIntegerv));

		Unix.Dlsym( oallib, "alcIsExtensionPresent", ADDRESSOF( alcIsExtensionPresentXXX));
		Unix.Dlsym( oallib, "alcGetProcAddress", ADDRESSOF( alcGetProcAddressXXX));
		Unix.Dlsym( oallib, "alcGetEnumValue", ADDRESSOF( alcGetEnumValue));

		Unix.Dlsym( oallib, "alcCaptureOpenDevice", ADDRESSOF( alcCaptureOpenDeviceXXX));
		Unix.Dlsym( oallib, "alcCaptureCloseDevice", ADDRESSOF( alcCaptureCloseDevice));
		Unix.Dlsym( oallib, "alcCaptureStart", ADDRESSOF( alcCaptureStart));
		Unix.Dlsym( oallib, "alcCaptureStop", ADDRESSOF( alcCaptureStop));
		Unix.Dlsym( oallib, "alcCaptureSamples", ADDRESSOF( alcCaptureSamples));

(*
		(* extensions *)
		Unix.Dlsym( oallib, "alBufferDataStatic", ADDRESSOF( alBufferDataStatic));
		Unix.Dlsym( oallib, "alcSetThreadContext", ADDRESSOF( alcSetThreadContext));
		Unix.Dlsym( oallib, "alcGetThreadContext", ADDRESSOF( alcGetThreadContext));
		Unix.Dlsym( oallib, "alBufferSubDataSOFT", ADDRESSOF( alBufferSubDataSOFT));
*)

END LoadFunctions;

PROCEDURE OnClose;
BEGIN
 IF oallib # 0 THEN
       Unix.Dlclose(oallib);
       KernelLog.String(libname); KernelLog.String(' unloaded.'); KernelLog.Ln;
END;
END OnClose;

(* utilities, and wrappers  *)

PROCEDURE alcOpenDevice*( CONST deviceName: ARRAY OF CHAR ): ALCdevice;
VAR dev: ALCdevice;
BEGIN
	dev := alcOpenDeviceXXX( ADDRESSOF( deviceName[0] ) );
	RETURN dev
END alcOpenDevice;

PROCEDURE alcCaptureOpenDevice*( CONST deviceName: ARRAY OF CHAR; 
								frequency: ALCuint; format: ALCenum; buffersize: ALCsizei): ALCdevice; 
VAR dev: ALCdevice;
BEGIN
	dev := alcCaptureOpenDeviceXXX( ADDRESSOF( deviceName[0] ), frequency, format, buffersize );
	RETURN dev
END alcCaptureOpenDevice;

PROCEDURE alcIsExtensionPresent* (device : ALCdevice; CONST extName : ARRAY OF CHAR) : ALCboolean;
VAR res: ALCboolean;
BEGIN
	res := alcIsExtensionPresentXXX(device, ADDRESSOF(extName[0]));
	RETURN res;
END alcIsExtensionPresent;

PROCEDURE alcGetProcAddress* (device : ALCdevice; CONST funcName: ARRAY OF CHAR): ADDRESS;
VAR adr: ADDRESS;
BEGIN
	adr := alcGetProcAddressXXX (device, ADDRESSOF(funcName[0]));
	RETURN adr;
END alcGetProcAddress;

(* Get string from address *)
PROCEDURE GetStringFromAddr(adr: ADDRESS): Strings.String;
VAR  sadr, sadr1: ADDRESS;
		i, cnt: LONGINT;
		ch: CHAR;
		s: Strings.String;
BEGIN
	sadr := adr;

	(* find length *)
	cnt :=0;
	sadr1 := sadr;
	IF sadr1 # 0 THEN
		SYSTEM.GET(sadr1,ch);
		WHILE (ch # 0X) DO  INC(cnt); INC(sadr1); SYSTEM.GET(sadr1,ch); END;
	END;

	IF cnt = 0 THEN  (* empty string *)
		NEW(s,1); s[0]:=0X; 	RETURN s
	END;

	NEW(s, cnt+1);
	i:=0;
	sadr1 := sadr;
	SYSTEM.GET(sadr1,ch);
	WHILE (i< cnt) & (ch # 0X) DO
		s^[i] := ch; INC(i); INC(sadr1);
		SYSTEM.GET(sadr1,ch);
	END;
	RETURN s;

END GetStringFromAddr;


PROCEDURE ALGetString*( name: ALCenum): Strings.String;
VAR  sadr: LONGINT;
BEGIN
	sadr := alGetString( name);
	RETURN GetStringFromAddr(sadr);
END ALGetString;

PROCEDURE ALCGetString*(device: ALCdevice; name: ALCenum): Strings.String;
VAR  sadr: LONGINT;
BEGIN
	sadr := alcGetString(device, name);
	RETURN GetStringFromAddr(sadr);
END ALCGetString;


PROCEDURE GetDevStringFromAddr(adr: LONGINT): Strings.String;
VAR  sadr, sadr1: LONGINT;
		i, cnt: LONGINT;
		ch: CHAR;
		s: Strings.String;
BEGIN
	sadr := adr;

	(* find length *)
	cnt :=0;
	sadr1 := sadr;
	IF sadr1 # 0 THEN
		SYSTEM.GET(sadr1,ch);
		WHILE (ch # 0X) DO  INC(cnt); INC(sadr1); SYSTEM.GET(sadr1,ch); END;
	END;

	IF cnt = 0 THEN  (* empty string or end of list *)
		RETURN NIL
	END;

	(* copy chars to string *)
	NEW(s, cnt+1);
	i:=0;
	sadr1 := sadr;
	SYSTEM.GET(sadr1,ch);
	WHILE (i< cnt) & (ch # 0X) DO
		s^[i] := ch; INC(i); INC(sadr1);
		SYSTEM.GET(sadr1,ch);
	END;
	RETURN s;

END GetDevStringFromAddr;

(** go through device list,  (each device terminated with a single NULL, list terminated with double NULL *)
PROCEDURE ALCGetDeviceList*(device: ALCdevice; name: ALCenum): PString256;
VAR  sadr, sadr0: LONGINT;
	slen, index: LONGINT;
	str: Strings.String;
	dynstr: PString256;
BEGIN

		(* count the number of devices in the list *)
		sadr0 := alcGetString(device, name);
		sadr := sadr0;
		str := GetDevStringFromAddr(sadr);
		index := 0;
		WHILE (str  # NIL) & (index<10)  DO (* limit the count *)
      			slen := Strings.Length(str^);
			sadr := sadr + slen +1;
			str := GetDevStringFromAddr(sadr);
			INC(index);
		END;


		(* copy to string list *)
		NEW(dynstr, index);
		sadr0 := alcGetString(device, name);
		sadr := sadr0;
		str := GetDevStringFromAddr(sadr);
		index := 0;
		WHILE (str  # NIL) & (index<10)  DO
		       COPY(str^, dynstr^[index]);
      			slen := Strings.Length(str^);
			sadr := sadr + slen +1;
			str := GetDevStringFromAddr(sadr);
			INC(index);
		END;

	RETURN dynstr;
END ALCGetDeviceList;


BEGIN
LoadFunctions;
Modules.InstallTermHandler(OnClose) ;

END OpenAL.

SystemTools.Free OpenAL~

