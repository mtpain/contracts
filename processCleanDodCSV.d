/**
 * Functions for processing the raw csv files gotten through scraping of the
 * DoD site http://www.defense.gov/contracts/, built using python script 
 * dod_contracts_ts.py
 */
module processCleanDodCSV;


import std.algorithm : canFind, equal, filter, findSplitBefore, findSplitAfter,
    map, reduce;
import std.array : array, join;
import std.ascii : letters;
import std.conv : to;
import std.csv : csvReader;
import std.datetime : Month, DateTime, SysTime, UTC;
import std.exception : enforce;
import std.getopt;
import std.math : approxEqual;
import std.range : chunks, drop, take;
import std.string : format, removechars, split, strip, toLower;
import std.stdio; 

/**
 * Convert the 'word dates' found in the 'Date' column of the raw csv to 
 * unix time epochs for use with Rickshaw/d3
 */
void main(string[] args)
{
    string inputFile, outputFile;
    bool cleanFirst;
    getopt( args,
        "inputFile|i", &inputFile, 
        "outputFile|o", &outputFile
    );

    processCleanFile(inputFile, outputFile);
}

/**
 * Process a cleaned file that's been cleaned by cleanRawDodCSV.d
 */
void processCleanFile(string inputPath, string outputPath)
{
	// by line read the clean announcement and process it
	// now we use csv reader
    auto csvLines = File(inputPath, "r").byLine();
    enforce (csvLines.front == "Date,Dollar Amount,Full Description",
        "Column titles must be 'Date','Dollar Amount','Full Description'"
    );
    auto outFile = File( outputPath, "w" );
    outFile.writeln("Date,Amount,Contractor");
    csvLines.popFront();

    uint exceptions, lines;
    foreach (row; csvLines)
    {
        try {
            outFile.writeln( 
                processAnnouncement( 
                    csvReader!RawContractAnnouncement( 
                        row.idup.removechars("\"") ).front 
                )
            );
        }

        catch(core.exception.RangeError) {
        	continue;
            exceptions++;
        }

        catch(std.conv.ConvException) {
        	exceptions++;
        	continue;
        }

        lines++;
    }

    writefln("%s out of %s lines threw an exception. Success Rate: %2.2f%%",
        exceptions, lines, (lines.to!double - exceptions.to!double)/lines.to!double * 100);

}

string processAnnouncement(RawContractAnnouncement ra)
{
	writeln(ra.date);
	string fd;
	//if (canFind(ra.fullDescription.split(" "), "The"))
		//fd = ra.fullDescription.split("The ")[1 .. $].join(" ");


    return [ format("%.8f", ra.date.wordDateToEpoch), // unix-time epoch
                ra.dollarAmount
                  .removechars(letters)
                  .removechars("/--;).*")
                  ~ ".0",                // contract value
                ra.fullDescription.removechars(";") // company name
                  .split(",")[0]
                  .findSplitAfter("The ")[1]
                  .findSplitBefore("Co.")[0]
                  .findSplitBefore("Corp.")[0]
                  .findSplitBefore("L.L.C.")[0]
                  .findSplitBefore("Inc.")[0]
                  .findSplitBefore("LLC")[0]
                  .findSplitBefore("Corporation")[0]
                  .findSplitBefore("Company")[0]
            ]
         .join(",");
}
unittest {
    RawContractAnnouncement ra;
    ra.date = "June 10 2011";
    ra.dollarAmount = "1000000000.0000900"; //1_000_000.00009000001;	
    const string dateStr = SysTime( DateTime(2011, 6, 10), UTC() ).toUnixTime.to!string
                            ~ ".00000000";
    const string dollarStr = "1000000.00009000";
    const string procStr = dateStr ~ "," ~ dollarStr;
    assert ( equal( ra.processAnnouncement, procStr ), "Processed announcement: "
        ~ ra.processAnnouncement ~ "\nnot equivalent to manual proc string: "
        ~ procStr
    );
}

double wordDateToEpoch(string wordDate)
{
    string[] spl = wordDate.split(" ");
    return SysTime( 
        DateTime(spl[2].to!uint, spl[0].getMonth, spl[1].to!uint),
        UTC()
        ).toUnixTime;
}
unittest {
	double nov10_2013 = SysTime( DateTime(2013, 11, 10), UTC() ).toUnixTime;
    assert ( wordDateToEpoch("november 10 2013") == nov10_2013);

    double apr01_1970 = SysTime( DateTime(1970, 4,  1), UTC() ).toUnixTime;
    assert ( wordDateToEpoch("April 01 1970") == apr01_1970);
}

/**
 * Convert a 'word month', e.g. February, to its representative Month enum
 * member from std.datetime.
 */
ubyte getMonth( string monthWord )
{
    switch (monthWord.toLower) {
    	default:
    	    throw new Exception("An invalid month was found: " ~ monthWord);

        case "january": return Month.jan;
        case "february": return Month.feb;
        case "march": return Month.mar;
        case "april": return Month.apr;
        case "may": return Month.may;
        case "june": return Month.jun;
        case "july": return Month.jul;
        case "august": return Month.aug;
        case "september": return Month.sep;
        case "october": return Month.oct;
        case "november": return Month.nov;
        case "december": return Month.dec;
    }
}

unittest {
	import std.exception;

    assertThrown( getMonth("hooziewhatsit") );
    assertThrown( getMonth("janury")        );

    assert( getMonth("JaNuAry")  ==  Month.jan);
    assert( getMonth("February") ==  Month.feb);
    assert(getMonth("March")     ==  Month.mar);
    assert(getMonth("April")     ==  Month.apr);
    assert(getMonth("May")       ==  Month.may);
    assert(getMonth("june")      ==  Month.jun);
    assert(getMonth("july")      ==  Month.jul);
    assert(getMonth("august")    ==  Month.aug);
    assert(getMonth("September") ==  Month.sep);
    assert(getMonth("October")   ==  Month.oct);
    assert(getMonth("November")  ==  Month.nov);
    assert(getMonth("December")  ==  Month.dec);
}

struct RawContractAnnouncement
{
    string date;
    //double dollarAmount;
    string dollarAmount;
    string fullDescription;
}