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
    
