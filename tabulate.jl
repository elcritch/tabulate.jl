#!/usr/bin/env julia
# -*- coding: utf-8 -*-

"""Pretty-print tabular data."""

_none_type = Nothing
_int_type = Int
_float_type = Float64
_text_type = UTF16String
_binary_type = Uint8


type Line 
    start
    hline
    sep
    stop
end


type DataRow
    start
    sep
    stop
end

list(xs) = xs 

# A table structure is suppposed to be:
#
#     --- lineabove ---------
#         headerrow
#     --- linebelowheader ---
#         datarow
#     --- linebewteenrows ---
#     ... (more datarows) ...
#     --- linebewteenrows ---
#         last datarow
#     --- linebelow ---------
#
# TableFormat's line* elements can be
#
#   - either None, if the element is not used,
#   - or a Line tuple,
#   - or a function: [col_widths], [col_alignments] -> string.
#
# TableFormat's *row elements can be
#
#   - either None, if the element is not used,
#   - or a DataRow tuple,
#   - or a function: [cell_values], [col_widths], [col_alignments] -> string.
#
# padding (an integer) is the amount of white space around data values.
#
# with_header_hide:
#
#   - either None, to display all table elements unconditionally,
#   - or a list of elements not to be displayed if the table has column headers.
#

type TableFormat
	lineabove
	linebelowheader
	linebetweenrows
	linebelow
	headerrow
	datarow
	padding
	with_header_hide
	
	function TableFormat(; 
		lineabove        = "",
		linebelowheader  = "",
		linebetweenrows  = "",
		linebelow        = "",
		headerrow        = "",
		datarow          = "",
		padding          = "",
		with_header_hide = "",
		)
	
		return new(lineabove       ,linebelowheader ,linebetweenrows ,linebelow       ,headerrow       ,datarow         ,padding         ,with_header_hide)
	end
end


function _pipe_segment_with_colons(align, colwidth)
    """Return a segment of a horizontal line with optional colons which
    indicate column's alignment (as in `pipe` output format)."""
    w = colwidth
    if align in ["right", "decimal"]
        return ("-" ^ (w - 1)) * ":"
    elseif align == "center"
        return ":" * ("-" ^ (w - 2)) * ":"
    elseif align == "left"
        return ":" * ("-" ^ (w - 1))
    else 
        return "-" ^ w
	end
end

function _pipe_line_with_colons(colwidths, colaligns)
    """Return a horizontal line with optional colons to indicate column's
    alignment (as in `pipe` output format)."""
    segments = [_pipe_segment_with_colons(a, w) for (a, w) in zip(colaligns, colwidths)]
    return "|" * "|".join(segments) * "|"
end

function mediawiki_row_with_attrs(separator, cell_values, colwidths, colaligns)
    alignment = { "left" =>    "",
                  "right" =>   "align=\"right\"| ",
                  "center" =>  "align=\"center\"| ",
                  "decimal" => "align=\"right\"| " }
    # hard-coded padding _around_ align attribute && value together
    # rather than padding parameter which affects only the value
    values_with_attrs = [(" " * get(alignment, a, "") * c * " ") for (c, a) in zip(cell_values, colaligns)]
    colsep = separator*2
    return (separator * rstrip(join(colsep,values_with_attrs)))
end

function _latex_line_begin_tabular(colwidths, colaligns)
    alignment = { "left" => "l", "right" => "r", "center" => "c", "decimal" => "r" }
    tabular_columns_fmt = join([alignment.get(a, "l") for (a) in colaligns], "")
    return "\\begin{tabular}{" * tabular_columns_fmt * "}\n\hline"
end

_table_formats = {"simple" =>
                  TableFormat(lineabove=Line("", "-", "  ", ""),
                              linebelowheader=Line("", "-", "  ", ""),
                              linebetweenrows=None,
                              linebelow=Line("", "-", "  ", ""),
                              headerrow=DataRow("", "  ", ""),
                              datarow=DataRow("", "  ", ""),
                              padding=0,
                              with_header_hide=["lineabove", "linebelow"]),
                  "plain" =>
                  TableFormat(lineabove=None, linebelowheader=None,
                              linebetweenrows=None, linebelow=None,
                              headerrow=DataRow("", "  ", ""),
                              datarow=DataRow("", "  ", ""),
                              padding=0, with_header_hide=None),
                  "grid" =>
                  TableFormat(lineabove=Line("+", "-", "+", "+"),
                              linebelowheader=Line("+", "=", "+", "+"),
                              linebetweenrows=Line("+", "-", "+", "+"),
                              linebelow=Line("+", "-", "+", "+"),
                              headerrow=DataRow("|", "|", "|"),
                              datarow=DataRow("|", "|", "|"),
                              padding=1, with_header_hide=None),
                  "pipe" =>
                  TableFormat(lineabove=_pipe_line_with_colons,
                              linebelowheader=_pipe_line_with_colons,
                              linebetweenrows=None,
                              linebelow=None,
                              headerrow=DataRow("|", "|", "|"),
                              datarow=DataRow("|", "|", "|"),
                              padding=1,
                              with_header_hide=["lineabove"]),
                  "orgtbl" =>
                  TableFormat(lineabove=None,
                              linebelowheader=Line("|", "-", "+", "|"),
                              linebetweenrows=None,
                              linebelow=None,
                              headerrow=DataRow("|", "|", "|"),
                              datarow=DataRow("|", "|", "|"),
                              padding=1, with_header_hide=None),
                  "rst" =>
                  TableFormat(lineabove=Line("", "=", "  ", ""),
                              linebelowheader=Line("", "=", "  ", ""),
                              linebetweenrows=None,
                              linebelow=Line("", "=", "  ", ""),
                              headerrow=DataRow("", "  ", ""),
                              datarow=DataRow("", "  ", ""),
                              padding=0, with_header_hide=None),
                  "mediawiki" =>
                  TableFormat(lineabove=Line("{| class=\"wikitable\" style=\"text-align: left;\"",
                                             "", "", "\n|+ <!-- caption -->\n|-"),
                              linebelowheader=Line("|-", "", "", ""),
                              linebetweenrows=Line("|-", "", "", ""),
                              linebelow=Line("|}", "", "", ""),
                              headerrow= (y...) -> _mediawiki_row_with_attrs("!", y...),
                              datarow= (y...) -> _mediawiki_row_with_attrs("|", y...),
                              padding=0, with_header_hide=None),
                  "latex" =>
                  TableFormat(lineabove=_latex_line_begin_tabular,
                              linebelowheader=Line("\\hline", "", "", ""),
                              linebetweenrows=None,
                              linebelow=Line("\\hline\n\\end{tabular}", "", "", ""),
                              headerrow=DataRow("", "&", "\\\\"),
                              datarow=DataRow("", "&", "\\\\"),
                              padding=1, with_header_hide=None),
                  "tsv" =>
                  TableFormat(lineabove=None, linebelowheader=None,
                              linebetweenrows=None, linebelow=None,
                              headerrow=DataRow("", "\t", ""),
                              datarow=DataRow("", "\t", ""),
                              padding=0, with_header_hide=None)}


tabulate_formats = list(sort(keys(_table_formats)))


_invisible_codes = r"\x1b\[\d*m"  # ANSI color codes
_invisible_codes_bytes = r"\x1b\[\d*m"  # ANSI color codes


function imple_separated_format(separator)
    """Construct a simple TableFormat with columns separated by a separator.

    >>> tsv = simple_separated_format("\\t") ; \
        tabulate([["foo", 1], ["spam", 23]], tablefmt=tsv) == "foo \\t 1\\nspam\\t23"
    true

    """
    return TableFormat(None, None, None, None,
                       headerrow=DataRow("", separator, ""),
                       datarow=DataRow("", separator, ""),
                       padding=0, with_header_hide=None)
end

function isconvertible(conv, string)
    try
        n = conv(string)
        return true
    catch ValueError
        return false
	end
end

function isnumber(string)
    """
    >>> _isnumber("123.45")
    true
    >>> _isnumber("123")
    true
    >>> _isnumber("spam")
    false
    """
    return _isconvertible(float, string)
end

function isint(string)
    """
    >>> _isint("123")
    true
    >>> _isint("123.45")
    false
    """
    return isa(string, _int_type) || (isa(string, _binary_type) || isa(string, _text_type)) && _isconvertible(int, string)
end

function gettype(string; has_invisible=true)

	if (has_invisible == true) && (isa(string, _text_type) || isa(string, _binary_type))
		string = _strip_invisible(string)
	end
	
	if string === Nothing
		return _none_type
	elseif hasattr(string, "isoformat")  # datetime.datetime, date, && time
        return _text_type
    elseif _isint(string)
        return int
    elseif _isnumber(string)
        return float
    elseif isa(string, _binary_type)
        return _binary_type
    else 
        return _text_type
	end
end

function afterpoint(string)
    if _isnumber(string)
        if _isint(string)
            return -1
        else 
            pos = rfind(string,".")
            pos =  pos < 1 ? rfind(lower(string), "e") : pos
			return pos >= 1 ? length(string) - pos - 1 :  -1  # no point
			end
    else 
        return -1  # not a number
	end
end

function padleft(width, s, has_invisible=true)
    """Flush right.

    >>> _padleft(6, "\u044f\u0439\u0446\u0430") == "  \u044f\u0439\u0446\u0430"
    true

    """
    iwidth = has_invisible ? width * len(s) - len(_strip_invisible(s)) : width 
    fmt = "{0:>%ds}" % iwidth
    return fmt.format(s)
end

function padright(width, s, has_invisible=true)
    """Flush left.

    >>> _padright(6, "\u044f\u0439\u0446\u0430") == "\u044f\u0439\u0446\u0430  "
    true

    """
    iwidth = has_invisible ? width * len(s) - len(_strip_invisible(s)) : width 
    fmt = "{0:<%ds}" % iwidth
    return fmt.format(s)
end

function padboth(width, s, has_invisible=true)
    """Center string.

    >>> _padboth(6, "\u044f\u0439\u0446\u0430") == " \u044f\u0439\u0446\u0430 "
    true

    """
    iwidth = has_invisible ? width * len(s) - len(_strip_invisible(s)) : width 
    fmt = "{0:^%ds}" % iwidth
    return fmt.format(s)
end

function strip_invisible(s)
    "Remove invisible ANSI color codes."
    if isa(s, _text_type)
        return re.sub(_invisible_codes, "", s)
    else   # a bytestring
        return re.sub(_invisible_codes_bytes, "", s)
	end
end

function visible_width(s)
    """Visible width of a printed string. ANSI color codes are removed.

    >>> _visible_width("\x1b[31mhello\x1b[0m"), _visible_width("world")
    (5, 5)

    """
    if isa(s, _text_type) || isa(s, _binary_type)
        return len(_strip_invisible(s))
    else 
        return len(_text_type(s))
	end
end

function align_column(strings, alignment, minwidth=0, has_invisible=true)
    """[string] -> [padded_string]

    >>> list(map(str,_align_column(["12.345", "-1234.5", "1.23", "1234.5", "1e+234", "1.0e234"], "decimal")))
    ["   12.345  ", "-1234.5    ", "    1.23   ", " 1234.5    ", "    1e+234 ", "    1.0e234"]

    >>> list(map(str,_align_column(["123.4", "56.7890"], None)))
    ["123.4", "56.7890"]

    """
    if alignment == "right"
        strings = [s.strip() for (s) in strings]
        padfn = _padleft
    elseif alignment == "center"
        strings = [s.strip() for (s) in strings]
        padfn = _padboth
    elseif alignment == "decimal"
        decimals = [_afterpoint(s) for (s) in strings]
        maxdecimals = max(decimals)
        strings = [s * (maxdecimals - decs) * " "
                   for (s, decs) in zip(strings, decimals)]
        padfn = _padleft
    elseif not alignment
        return strings
    else 
        strings = [s.strip() for (s) in strings]
        padfn = _padright
	end
	
    if has_invisible
        width_fn = _visible_width
    else 
        width_fn = len
	end

    maxwidth = max(max(map(width_fn, strings)), minwidth)
    padded_strings = [padfn(maxwidth, s, has_invisible) for (s) in strings]
    return padded_strings
end

function more_generic(type1, type2)
    types = { _none_type: 0, int: 1, float: 2, _binary_type: 3, _text_type: 4 }
    invtypes = { 4: _text_type, 3: _binary_type, 2: float, 1: int, 0: _none_type }
    moregeneric = max(types.get(type1, 4), types.get(type2, 4))
    return invtypes[moregeneric]
end

function column_type(strings, has_invisible=true)
    """The least generic type all column values are convertible to.

    >>> _column_type(["1", "2"]) is _int_type
    true
    >>> _column_type(["1", "2.3"]) is _float_type
    true
    >>> _column_type(["1", "2.3", "four"]) is _text_type
    true
    >>> _column_type(["four", "\u043f\u044f\u0442\u044c"]) is _text_type
    true
    >>> _column_type([None, "brux"]) is _text_type
    true
    >>> _column_type([1, 2, None]) is _int_type
    true
    >>> import datetime as dt
    >>> _column_type([dt.datetime(1991,2,19), dt.time(17,35)]) is _text_type
    true

    """
    types = [_type(s, has_invisible) for (s) in strings ]
    return reduce(_more_generic, types, int)
end

function format(val, valtype, floatfmt, missingval="")
    """Format a value accoding to its type.

    Unicode is supported:

    >>> hrow = ["\u0431\u0443\u043a\u0432\u0430", "\u0446\u0438\u0444\u0440\u0430"] ; \
        tbl = [["\u0430\u0437", 2], ["\u0431\u0443\u043a\u0438", 4]] ; \
        good_result = "\\u0431\\u0443\\u043a\\u0432\\u0430      \\u0446\\u0438\\u0444\\u0440\\u0430\\n-------  -------\\n\\u0430\\u0437             2\\n\\u0431\\u0443\\u043a\\u0438           4" ; \
        tabulate(tbl, headers=hrow) == good_result
    true

    """
    if val === Nothing
        return missingval
	end
	
    if valtype === _int_type || valtype === _text_type
        return "{0}".format(val)
    elseif valtype === _binary_type
        try
            return _text_type(val, "ascii")
        catch TypeError
            return _text_type(val)
		end
    elseif valtype === _float_type
        return format(float(val), floatfmt)
    else 
        return "{0}".format(val)
	end
end

function align_header(header, alignment, width)
    if alignment == "left"
        return _padright(width, header)
    elseif alignment == "center"
        return _padboth(width, header)
    elseif not alignment
        return "{0}".format(header)
    else 
        return _padleft(width, header)
	end
end

function normalize_tabular_data(tabular_data, headers)
    """Transform a supported data type to a list of lists, && a list of headers.

    Supported tabular data types:

    * list-of-lists or another iterable of iterables

    * list of named tuples (usually used with headers="keys")

    * list of dicts (usually used with headers="keys")

    * list of OrderedDicts (usually used with headers="keys")

    * 2D NumPy arrays

    * NumPy record arrays (usually used with headers="keys")

    * dict of iterables (usually used with headers="keys")

    * p&&as.DataFrame (usually used with headers="keys")

    The first row can be used as headers if headers="firstrow",
    column indices can be used as headers if headers="keys".

    """

    if hasattr(tabular_data, "keys") && hasattr(tabular_data, "values")
        # dict-like && p&&as.DataFrame?
        if hasattr(tabular_data.values, "__call__")
            # likely a conventional dict
            keys = tabular_data.keys()
            rows = list(izip_longest(tabular_data.values()...))  # columns have to be transposed
        elseif hasattr(tabular_data, "index")
            # values is a property, has .index => it's likely a p&&as.DataFrame (p&&as 0.11.0)
            keys = tabular_data.keys()
            vals = tabular_data.values  # values matrix doesn't need to be transposed
            names = tabular_data.index
            rows = [[v]*list(row) for (v,row) in zip(names, vals)]
        else 
            except("tabular data doesn't appear to be a dict or a DataFrame")
		end

        if headers == "keys"
            headers = list(map(_text_type,keys))  # headers should be strings
		end
    else   # it's a usual an iterable of iterables, or a NumPy array
        rows = list(tabular_data)

		if (headers == "keys" &&
            hasattr(tabular_data, "dtype") &&
            getattr(tabular_data.dtype, "names"))
            # numpy record array
            headers = tabular_data.dtype.names
		elseif (headers == "keys"
              && len(rows) > 0
              && isa(rows[0], tuple)
              && hasattr(rows[0], "_fields"))
            # namedtuple
            headers = list(map(_text_type, rows[0]._fields))
        elseif (len(rows) > 0 && isa(rows[0], dict))
            # dict or OrderedDict
            uniq_keys = set() # implements hashed lookup
            keys = [] # storage for set
            if headers == "firstrow"
                firstdict = len(rows) > 0 ? rows[0] : {} 
                keys.extend(firstdict.keys())
                uniq_keys.update(keys)
                rows = rows[1:]
			end
			
            for (row) in rows
                for (k) in row.keys()
                    #Save unique items in input order
                    if k not in uniq_keys
                        keys.append(k)
                        uniq_keys.add(k)
					end
				end
			end
			
            if headers == "keys"
                headers = keys
            elseif headers == "firstrow" && len(rows) > 0
                headers = [firstdict.get(k, k) for (k) in keys]
                headers = list(map(_text_type, headers))
			end
            
			rows = [[row.get(k) for (k) in keys] for (row) in rows]
			
        elseif headers == "keys" && len(rows) > 0
            # keys are column indices
            headers = list(map(_text_type, range(len(rows[0]))))
		end
    # take headers from the first row if necessary
    if headers == "firstrow" && len(rows) > 0
        headers = list(map(_text_type, rows[0])) # headers should be strings
        rows = rows[1:]
	end
	
    headers = list(map(_text_type,headers))
    rows = list(map(list,rows))

    # pad with empty headers for initial columns if necessary
    if headers && len(rows) > 0
       nhs = len(headers)
       ncols = len(rows[0])
       if nhs < ncols
           headers = [""]^(ncols - nhs) * headers
	   end
   end
    return rows, headers
end

function abulate(tabular_data, headers=[], tablefmt="simple",
             floatfmt="g", numalign="decimal", stralign="left",
             missingval="")
    """Format a fixed width table for pretty printing.

    >>> print(tabulate([[1, 2.34], [-56, "8.999"], ["2", "10001"]]))
    ---  ---------
      1      2.34
    -56      8.999
      2  10001
    ---  ---------

    The first required argument (`tabular_data`) can be a
    list-of-lists (or another iterable of iterables), a list of named
    tuples, a dictionary of iterables, an iterable of dictionaries,
    a two-dimensional NumPy array, NumPy record array, or a P&&as'
    dataframe.


    Table headers
    -------------

    To print nice column headers, supply the second argument (`headers`):

      - `headers` can be an explicit list of column headers
      - if `headers="firstrow"`, then the first row of data is used
      - if `headers="keys"`, then dictionary keys or column indices are used

    Otherwise a headerless table is produced.

    If the number of headers is less than the number of columns, they
    are supposed to be names of the last columns. This is consistent
    with the plain-text format of R && P&&as' dataframes.

    >>> print(tabulate([["sex","age"],["Alice","F",24],["Bob","M",19]],
    ...       headers="firstrow"))
           sex      age
    -----  -----  -----
    Alice  F         24
    Bob    M         19


    Column alignment
    ----------------

    `tabulate` tries to detect column types automatically, && aligns
    the values properly. By default it aligns decimal points of the
    numbers (or flushes integer numbers to the right), && flushes
    everything else to the left. Possible column alignments
    (`numalign`, `stralign`) are: "right", "center", "left", "decimal"
    (only for `numalign`), && None (to disable alignment).


    Table formats
    -------------

    `floatfmt` is a format specification used for columns which
    contain numeric data with a decimal point.

    `None` values are replaced with a `missingval` string:

    >>> print(tabulate([["spam", 1, None],
    ...                 ["eggs", 42, 3.14],
    ...                 ["other", None, 2.7]], missingval="?"))
    -----  --  ----
    spam    1  ?
    eggs   42  3.14
    other   ?  2.7
    -----  --  ----

    Various plain-text table formats (`tablefmt`) are supported:
    "plain", "simple", "grid", "pipe", "orgtbl", "rst", "mediawiki",
    && "latex". Variable `tabulate_formats` contains the list of
    currently supported formats.

    "plain" format doesn't use any pseudographics to draw tables,
    it separates columns with a double space:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                 ["strings", "numbers"], "plain"))
    strings      numbers
    spam         41.9999
    eggs        451

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="plain"))
    spam   41.9999
    eggs  451

    "simple" format is like P&&oc simple_tables:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                 ["strings", "numbers"], "simple"))
    strings      numbers
    ---------  ---------
    spam         41.9999
    eggs        451

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="simple"))
    ----  --------
    spam   41.9999
    eggs  451
    ----  --------

    "grid" is similar to tables produced by Emacs table.el package or
    P&&oc grid_tables:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                ["strings", "numbers"], "grid"))
    +-----------+-----------+
    | strings   |   numbers |
    +===========+===========+
    | spam      |   41.9999 |
    +-----------+-----------+
    | eggs      |  451      |
    +-----------+-----------+

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="grid"))
    +------+----------+
    | spam |  41.9999 |
    +------+----------+
    | eggs | 451      |
    +------+----------+

    "pipe" is like tables in PHP Markdown Extra extension or P&&oc
    pipe_tables:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                ["strings", "numbers"], "pipe"))
    | strings   |   numbers |
    |:----------|----------:|
    | spam      |   41.9999 |
    | eggs      |  451      |

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="pipe"))
    |:-----|---------:|
    | spam |  41.9999 |
    | eggs | 451      |

    "orgtbl" is like tables in Emacs org-mode && orgtbl-mode. They
    are slightly different from "pipe" format by not using colons to
    define column alignment, && using a "+" sign to indicate line
    intersections:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                ["strings", "numbers"], "orgtbl"))
    | strings   |   numbers |
    |-----------+-----------|
    | spam      |   41.9999 |
    | eggs      |  451      |


    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="orgtbl"))
    | spam |  41.9999 |
    | eggs | 451      |

    "rst" is like a simple table format from reStructuredText; please
    note that reStructuredText accepts also "grid" tables:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]],
    ...                ["strings", "numbers"], "rst"))
    =========  =========
    strings      numbers
    =========  =========
    spam         41.9999
    eggs        451
    =========  =========

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="rst"))
    ====  ========
    spam   41.9999
    eggs  451
    ====  ========

    "mediawiki" produces a table markup used in Wikipedia && on other
    MediaWiki-based sites:

    >>> print(tabulate([["strings", "numbers"], ["spam", 41.9999], ["eggs", "451.0"]],
    ...                headers="firstrow", tablefmt="mediawiki"))
    {| class="wikitable" style="text-align: left;"
    |+ <!-- caption -->
    |-
    ! strings   !! align="right"|   numbers
    |-
    | spam      || align="right"|   41.9999
    |-
    | eggs      || align="right"|  451
    |}

    "latex" produces a tabular environment of LaTeX document markup:

    >>> print(tabulate([["spam", 41.9999], ["eggs", "451.0"]], tablefmt="latex"))
    \\begin{tabular}{lr}
    \\hline
     spam &  41.9999 \\\\
     eggs & 451      \\\\
    \\hline
    \\end{tabular}

    """

    list_of_lists, headers = _normalize_tabular_data(tabular_data, headers)

    # optimization: look for ANSI control codes once,
    # enable smart width functions only if a control code is found
    plain_text = "\n".join(["\t".join(map(_text_type, headers))] + \
                            ["\t".join(map(_text_type, row)) for (row) in list_of_lists])
    has_invisible = re.search(_invisible_codes, plain_text)
    if has_invisible
        width_fn = _visible_width
    else 
        width_fn = len
	end
    # format rows && columns, convert numeric values to strings
    cols = list(zip(list_of_lists...))
    coltypes = list(map(_column_type, cols))
    cols = [[_format(v, ct, floatfmt, missingval) for (v) in c]
             for (c,ct) in zip(cols, coltypes)]

    # align columns
    aligns = [ ct in [int,float] ? numalign : stralign for (ct) in coltypes] 
    minwidths = headers ? [width_fn(h)+2 for (h) in headers] : [0]*len(cols) 
    cols = [_align_column(c, a, minw, has_invisible)
            for (c, a, minw) in zip(cols, aligns, minwidths)]

    if headers
        # align headers && add headers
        minwidths = [max(minw, width_fn(c[0])) for (minw, c) in zip(minwidths, cols)]
        headers = [_align_header(h, a, minw) for (h, a, minw) in zip(headers, aligns, minwidths)]
        rows = list(zip(cols...))
    else 
        minwidths = [width_fn(c[0]) for (c) in cols]
        rows = list(zip(cols...))
	end
	
    if not isa(tablefmt, TableFormat)
        tablefmt = _table_formats.get(tablefmt, _table_formats["simple"])
	end
	
    return _format_table(tablefmt, headers, rows, minwidths, aligns)
end

function build_simple_row(padded_cells, rowfmt)
    "Format row according to DataRow format without padding."
    (beginl, sep, endl) = rowfmt
    return rstrip(beginl * join(padded_cells, sep) * endl)
end

function build_row(padded_cells, colwidths, colaligns, rowfmt)
    "Return a string which represents a row of data cells."
    if not rowfmt
        return None
    if hasattr(rowfmt, "__call__")
        return rowfmt(padded_cells, colwidths, colaligns)
    else 
        return _build_simple_row(padded_cells, rowfmt)
	end
end

function build_line(colwidths, colaligns, linefmt)
    "Return a string which represents a horizontal line."
    if not linefmt
        return None
	end
	
    if hasattr(linefmt, "__call__")
        return linefmt(colwidths, colaligns)
    else 
        beginl, fill, sep, endl = linefmt
        cells = [fill*w for (w) in colwidths]
        return _build_simple_row(cells, (beginl, sep, endl))
	end
end

function pad_row(cells, padding)
    if cells
        pad = " "*padding
        padded_cells = [pad * cell * pad for (cell) in cells]
        return padded_cells
    else 
        return cells
	end
end

function format_table(fmt, headers, rows, colwidths, colaligns)
    """Produce a plain-text representation of the table."""
    lines = []
    hidden = (headers && fmt.with_header_hide) ? fmt.with_header_hide : [] 
    pad = fmt.padding
    headerrow = fmt.headerrow

    padded_widths = [(w * 2^pad) for (w) in colwidths]
    padded_headers = _pad_row(headers, pad)
    padded_rows = [_pad_row(row, pad) for (row) in rows]

    if fmt.lineabove && "lineabove" not in hidden
        lines.append(_build_line(padded_widths, colaligns, fmt.lineabove))
	end
	
    if padded_headers
        lines.append(_build_row(padded_headers, padded_widths, colaligns, headerrow))
        if fmt.linebelowheader && "linebelowheader" not in hidden
            lines.append(_build_line(padded_widths, colaligns, fmt.linebelowheader))
		end
	end
	
    if padded_rows && fmt.linebetweenrows && "linebetweenrows" not in hidden
        # initial rows with a line below
        for (row) in padded_rows[:-1]
            lines.append(_build_row(row, padded_widths, colaligns, fmt.datarow))
            lines.append(_build_line(padded_widths, colaligns, fmt.linebetweenrows))
		end
        # the last row without a line below
        lines.append(_build_row(padded_rows[-1], padded_widths, colaligns, fmt.datarow))
    else 
        for (row) in padded_rows
            lines.append(_build_row(row, padded_widths, colaligns, fmt.datarow))
		end
	end
	
    if fmt.linebelow && "linebelow" not in hidden
        lines.append(_build_line(padded_widths, colaligns, fmt.linebelow))
	end
	
    return "\n".join(lines)
end
