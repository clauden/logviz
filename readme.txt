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
    
Syntax:

Define global column delimiter
  DELIMITER some-regex-or-character
Define a regular expression
  REGEXP some-tag some-regexp

Assign a label to a column
  LABEL some-tag COLUMN some-column
Assign a label to an expression 
  LABEL some-tag EXPR some-expr
Assign a label to a JSON expression against current row
  LABEL some-tag JSON json-expr
Assign a label to a regular expression capture
  LABEL some-tag REGEXP regexp-tag match-index 

Set timeseries mode
  TIMESERIES true-or-false

Set x axis 
  XAXIS some-tag label 
Set y axis
  YAXIS some-tag label


