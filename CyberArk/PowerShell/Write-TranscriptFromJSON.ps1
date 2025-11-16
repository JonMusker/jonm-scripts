[CmdletBinding()]param(
    [string]$InFile, 
    [string]$OutFile, 
    [ValidateSet("Present","None")][string]$Pauses = "Present", 
    [ValidateSet("FixedWidth","CSV")][string]$OutputType = "CSV",
    [double]$SilenceThresholdMilliseconds 
)

$FORMAT_STRING = "{0:mm:ss} {1} - {2}"
$HEADER_LINE    = '"start_time","end_time","duration","speaker","text"'
$FORMAT_STRING_PAUSE = "[Pause {0:#0.0}s] "
$DEFAULT_SILENCE_THRESHOLD_CSV   = 0.2
$DEFAULT_SILENCE_THRESHOLD_FIXED = 2

if($SilenceThresholdMilliseconds -gt 99){
    $SILENCE_THRESHOLD_SECONDS = $SilenceThresholdMilliseconds / 1000
} else {
    if($OutputType.ToLower() -eq "csv"){
        $SILENCE_THRESHOLD_SECONDS = $DEFAULT_SILENCE_THRESHOLD_CSV
    } else {
        $SILENCE_THRESHOLD_SECONDS = $DEFAULT_SILENCE_THRESHOLD_FIXED
    }
}
#validate file data
if(! (test-path $InFile)) { Throw "File '$InFile' not found. Cannot continue" }
if($OutFile.Length -eq 0) { 
    if($OutputType.ToLower() -eq "csv"){
        $OutFile = $InFile.Replace(".json",".csv")
    } else {
        #Throw "FixedWidth output not supported yet"
        $OutFile = $InFile.Replace(".json",".txt")
    }
}
if($OutFile.Length -lt 5) { Throw "'$OutFile' -OutFile parameter must be a filename" }
if(test-path $OutFile) { del $OutFile }
if(test-path $OutFile)    { Throw "Cannot delete file '$OutFile'. Cannot continue" }

#read in the raw material
$JSON = ConvertFrom-Json (GC $InFile -raw)
if($JSON.results -eq $null -or $JSON.results.transcripts.Count -ne 1 -or $JSON.results.items.Count -lt 10) {Throw "Could not load valid JSON from file '$InFile'. Ensure this file is the results from AWS Transcript"}
$itms = $JSON.results.audio_segments

$Zero = [datetime]::new(0)  
$LastEndTime = $zero
$OutText = New-Object System.Text.StringBuilder

if($OutputType.ToLower() -eq "fixedwidth"){
    #Human-readable output
    $Segment = "" | Select Speaker,Start,End,Duration,Text
    $Segment.Speaker  = $itms[0].speaker_label
    $Segment.Start    = 0
    $Segment.End      = $itms[0].end_time
    $Segment.Text     = ""

    foreach ($Item in $itms)
    {
        if($Item.speaker_label -ne $Segment.Speaker){
            #Start of a new segment. Commit the current segment and start a new one
            $CurrLine = [String]::Format($FORMAT_STRING,$Zero.AddSeconds([double]$Segment.Start),$Segment.Speaker,$Segment.Text)
	        $ignore   = $OutText.AppendLine($CurrLine)

            $Segment.Speaker  = $Item.speaker_label
            $Segment.Start    = $Item.start_time
            $Segment.End      = $Item.end_time
            $Segment.Text     = ""
        }

	    #add pause between lines (if non-zero)
        $pausetext = " "
        $end_time  = $Zero.AddSeconds([double]$Item.start_time)
	    $Duration  = ($end_time - $LastEndTime).TotalSeconds
        if($Duration -gt $SILENCE_THRESHOLD_SECONDS) {
            if($Pauses.ToLower() -eq "present") {
                $pausetext = [String]::Format($FORMAT_STRING_PAUSE,$Duration)
            } else {
                #pauses ignored - take no action
            }
        }
    	
	    #add the actual line
	    $start_time  = $Zero.AddSeconds([double]$Item.start_time)
        $end_time    = $Zero.AddSeconds([double]$Item.end_time)
	    $Duration    = ($end_time - $start_time).TotalSeconds

        $Segment.End      =  $end_time
        $Segment.Text     += $pausetext + $Item.Transcript        

        $LastEndTime = $end_time
    }
    #Append final item in buffer
    $CurrLine = [String]::Format($FORMAT_STRING,$Zero.AddSeconds([double]$Segment.Start),$Segment.Speaker,$Segment.Text)
    $ignore   = $OutText.AppendLine($CurrLine)

} else {
    #CSV Output
    $OutItems = @()
    $ignore=$OutText.AppendLine($HEADER_LINE)
    foreach ($Item in $itms)
    {
	    #add pause between lines (if non-zero)
        $pausetext = ""
        $end_time  = $Zero.AddSeconds([double]$Item.start_time)
	    $Duration  = ($end_time - $LastEndTime).TotalSeconds
        if($Duration -gt $SILENCE_THRESHOLD_SECONDS) {
            if($Pauses.ToLower() -eq "present") {
                $PauseItem = "" | select StartTime,EndTime,Duration,Speaker,WordCount,Text
                $PauseItem.StartTime = [String]::Format("{0:mm:ss:fff}",$LastEndTime)
                $PauseItem.EndTime   = [String]::Format("{0:mm:ss:fff}",$end_time)
                $PauseItem.Duration  = $Duration
                $PauseItem.Speaker   = "pause"
                $PauseItem.WordCount = 0
                $PauseItem.Text      = ""
                $OutItems += $PauseItem
            } else {
                #pauses ignored - take no action
            }
        }
    	
	    #add the actual line
	    $start_time = $Zero.AddSeconds([double]$Item.start_time)
        $end_time   = $Zero.AddSeconds([double]$Item.end_time)
	    $Duration   = ($end_time - $start_time).TotalSeconds
	    $CurrSpeaker = $Item.speaker_label
	    $text      = $pausetext + $Item.Transcript

        $NewItem = "" | select StartTime,EndTime,Duration,Speaker,WordCount,Text
        $NewItem.StartTime = [String]::Format("{0:mm:ss:fff}",$LastEndTime)
        $NewItem.EndTime   = [String]::Format("{0:mm:ss:fff}",$end_time)
        $NewItem.Duration  = $Duration
        $NewItem.Speaker   = $CurrSpeaker
        $NewItem.WordCount = $Item.Transcript | Measure-Object -Word | select -ExpandProperty words
        $NewItem.Text      = $text
        $OutItems += $NewItem

        $LastEndTime = $end_time
    }
}

if($OutputType.ToLower() -eq "csv") {
    $OutItems | export-csv -NoTypeInformation -Path $OutFile
} else {
    $OutText.ToString() > $OutFile
}
