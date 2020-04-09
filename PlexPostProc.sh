#!/bin/bash

#******************************************************************************
#******************************************************************************
#
#            Plex DVR Post Processing Script
#   
# Author: nebhead
#******************************************************************************
#******************************************************************************
#
#  Version: 2.1
#
#  Pre-requisites:
#     ffmpeg
#
#  Usage:
#     'PlexPostProc.sh %1'
#
#  Description:
#
#      1. Creates a temporary directory, WORKDIR, for
#      the show it is about to transcode.
#
#      2. Copies the original file into WORKDIR so it won't be removed by
#      Plex if another script instance finishes before this one.
#
#      3. Uses the selected encoder to transcode the original, very
#      large MPEG2 format file to a smaller, more manageable H.264 mp4 file
#      (which can be streamed to various devices more easily).
#
#      4. Copies the file back to the original .grab folder for final move by Plex
#      to a library.
#
#  Log:
#     Logs will be generated in LOGDIR for each encode with the format of LOGFILE
#    
#     Note: DAYS old logs from prior runs are deleted by the current run. This
#     should be a cron job, but let's keep it simple.
#
#******************************************************************************

# Source (original) file information
ORIGDIR="dirname $1"
ORIGFILE="basename $1"
ORIGFILEPATH="$1"

WORKDIR="/opt/plexmedia/dvr/work"
INWORKFILEPATH="$WORKDIR/$ORIGFILE"
OUTWORKFILEPATH="$(mktemp $WORKDIR/ffmpeg.XXXX.mkv)"

DAYS=1
LOGDIR="/var/log/plexmedia"
LOGFILE=post-process-script-$(date +"%d-%H%M%S").log
LOGFILEPATH="$LOGDIR/$LOGFILE"
touch $LOGFILE # Create the log file

#******************************************************************************

check_errs()
{
        # Function. Parameter 1 is the return code
        # Para. 2 is text to display on failure
        if [ "${1}" -ne "0" ]; then
           echo "ERROR # ${1} : ${2}" | tee -a $LOGFILE
           exit ${1}
        fi
}

if [ ! -z "$1" ]; then
# The if selection statement proceeds to the script if $1 is not empty.
   if [ ! -f "$1" ]; then 
      fatal "$1 does not exist"
   fi
   # The above if selection statement checks if the file exists before proceeding. 

   # Uncomment if you want to adjust the bandwidth for this thread
   #MYPID=$$	# Process ID for current script
   # Adjust niceness of CPU priority for the current process
   #renice 19 $MYPID
   
   # ********************************************************
   # Move source file to work directory
   # ********************************************************
   
   mv -f "$ORIGFILEPATH" "$INWORKFILEPATH" # Move source file to work directory
   check_errs $? "Failed to move source to workdirectory file: $INWORKFILEPATH"

   # ********************************************************
   # Starting Transcoding
   # ********************************************************

   echo "$(date +"%Y%m%d-%H%M%S"): Starting transcode of $ORIGFILEPATH to $OUTWORKFILEPATH" | tee -a $LOGFILEPATH
   if [[ $ENCODER == "handbrake" ]]; then
#     echo "You have selected HandBrake" | tee -a $LOGFILE
#     HandBrakeCLI -i "$FILENAME" -f mkv --aencoder copy -e qsv_h264 --x264-preset veryfast --x264-profile auto -q 16 --maxHeight $RES --decomb bob -o "$TEMPFILENAME"
#     check_errs $? "Failed to convert using Handbrake."
   elif [[ $ENCODER == "ffmpeg" ]]; then
     echo "You have selected FFMPEG" | tee -a $LOGFILEPATH
     ffmpeg -i "$INWORKFILEPATH" -c:v libx264 -preset veryfast -c:a copy "$OUTWORKFILEPATH"
     check_errs $? "Failed to convert using FFMPEG."
   else
     echo "Oops, invalid ENCODER string.  Using Default [FFMpeg]." | tee -a $LOGFILE
     ffmpeg -i "$FILENAME" -s hd$RES -c:v libx264 -preset veryfast -vf yadif -c:a copy "$TEMPFILENAME"
     check_errs $? "Failed to convert using FFMPEG."
   fi

   # ********************************************************"
   # Encode Done. Performing Cleanup
   # ********************************************************"

   echo "$(date +"%Y%m%d-%H%M%S"): Finished transcode of $ORIGFILEPATH to $OUTWORKFILEPATH" | tee -a $LOGFILEPATH

   mv -f "$OUTWORKFILEPATH" "${ORIGFILEPATH%.ts}.mp4" # Move completed tempfile to .grab folder/filename
   check_errs $? "Failed to move converted file: $OUTWORKFILEPATH"

   rm -f "$OUTWORKFILEPATH" # Delete source from working folder
   check_errs $? "Failed to remove working source file: $OUTWORKFILEPATH"

   find "$LOGDIR* -mtime $DAYS -delete"

   echo "$(date +"%Y%m%d-%H%M%S"): Encode done.  Exiting." | tee -a $LOGFILEPATH

else
   echo "********************************************************" | tee -a $LOGFILEPATH
   echo "PlexPostProc by nebhead" | tee -a $LOGFILEPATH
   echo "Usage: $0 FileName" | tee -a $LOGFILEPATH
   echo "********************************************************" | tee -a $LOGFILEPATH
fi
