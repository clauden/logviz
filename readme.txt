This project generates quick gnuplots of row-oriented data with a simple dsl.

It supports the following kinds of input:
. JSON (assumes an array of entries at the top level)
. delimited fields
. arbitrary fields parsed with regex captures

As time series plotting is common, timestamps can be used to generate proper timelines.

The specification dsl supports definition of:
  . column delimiter
  . labeled regexps
  . variables
    - column indexes
    - json expression (for each array entry)
    - regexp capture groups
  . x axis
    - time series 
    - variable
  . y axes (multiple, left/right)
  . output image file
    
Usage:
    logviz.rb --file <rules-file> --datafile <data-file> [--columns | --json] --gnuplot <cmd-file> --output <output-file> --imagefile <image-file> --run --DEBUG --quiet
  
    In the absence of --datafile, STDIN is read.
    In the absence of --gnuplot, the command file is written to 'gnuplot.cmd' in the local directory.
    In the absence of --output, the output data file is written to 'out' in the local directory.
    Gnuplot will be executed if --run is set.
    Gnuplot will output to tty unless --imagefile is set.

    Column input may be processed either with a fixed delimiter expression or using regexps.
    JSON input is assumed to be an array containing one hash per row. 

    X-axis may be timeseries (date/time format calculated automatically) or just data.

    Rules-file format:
      TIMESERIES [ "true" | "false" ]
      DELIMITER [ <regexp> | <character> ]
      REGEXP <tag> <regexp>

      COLUMN <tag> <col-num>    # Assign tag to a column in the input data
      EXPR <tag> <expr>         # Assign tag to an arbitrary expression (can contain defined tags)
      JSON <tag> <json-expr>    # Assign tag to a JSON expression against current "row"
      MATCH <tag> <regex-tag> <capture-group>     # Assign tag to the nth capture group of the specified regex (defined by REGEXP)

      XAXIS <tag> <label>             # Set x-axis data set to tag (exactly one required)
      YAXIS <tag> <label>             # Set left y-axis data set to tag (one or more)
      Y2AXIS <tag> <label>            # Set right y-axis data set to tag (one or more)

DSL rules file example:

  # define some elements to be extracted from JSON hashes (one hash per data row)
  JSON date e["date"]["end"]
  JSON allvoice e["voice"]["all"]

  # we can define an expression composing other elements
  JSON errs_other e["voice"]["other"]
  JSON errs_query e["voice"]["query"]
  JSON errs_asr e["voice"]["asr"]
  EXPR allerrs errs_other + errs_query + errs_asr 

  JSON newdevices e["devices"]["new"]
  JSON alldevices e["devices"]["all"]
  EXPR old_devices alldevices - newdevices

  # the X axis contains dates and times
  TIMESERIES true
  XAXIS date 

  # queries and errors go on the left-hand Y axis
  YAXIS allvoice "voice queries"
  YAXIS allerrs "errors"

  # new and old devices go on the right-hand Y axis
  Y2AXIS old_devices "returning devices"
  Y2AXIS newdevices "new devices"

  TITLE "Daily Activity"

JSON input data example:
  [
  {"voice":{"asr":88,"other":38,"avg":79,"ok":596,"duration":9.78,"query":41,"all":763},"text":{"avg":81,"ok":61,"server":12,"duration":6.56,"query":3,"all":76},"devices":{"old":81,"all":189,"new":108},"date":{"start":"2009-01-01T00:00:00+00:00","end":"2009-01-02T00:00:00+00:00"}}, 
  {"voice":{"asr":112,"other":59,"avg":75,"ok":691,"duration":9.58,"query":60,"all":922},"text":{"avg":86,"ok":73,"server":11,"duration":5.89,"query":1,"all":85},"devices":{"old":87,"all":204,"new":117},"date":{"start":"2009-01-02T00:00:00+00:00","end":"2009-01-03T00:00:00+00:00"}},
  {"voice":{"asr":91,"other":144,"avg":72,"ok":741,"duration":9.42,"query":56,"all":1032},"text":{"avg":71,"ok":78,"server":31,"duration":5.18,"query":2,"all":111},"devices":{"old":101,"all":229,"new":128},"date":{"start":"2009-01-03T00:00:00+00:00","end":"2009-01-04T00:00:00+00:00"}}
  ]

