using Godot;
using GDictionary = Godot.Collections.Dictionary;
using System;
using System.Numerics;
using System.Collections.Generic;



public partial class babel_math : Node
{
    private static Node global_values;

    private static string     cachedHex      = "";
    private static BigInteger cachedHexValue = BigInteger.Zero;

    private static string     cachedBookKey   = "";
    private static BigInteger cachedBookValue = BigInteger.Zero;

    private static Dictionary<int, BigInteger> pow29Cache = new Dictionary<int, BigInteger>();

    private static readonly Random Rng = new Random();

    private static readonly char[] Base29Characters = {
        'a','b','c','d','e','f','g','h','i','j','k','l','m',
        'n','o','p','q','r','s','t','u','v','w','x','y','z',
        ' ', ',', '.'
    };

    private static readonly int[] Base36Table = CreateBase36Table();
    private static readonly int[] Base29Table = CreateBase29Table();


    private static int[] CreateBase36Table()
    {
        int[] table = new int[128];
        for (int i = 0; i < table.Length; i++)
            table[i] = -1;

        for (int i = 0; i < 10; i++)
            table['0' + i] = i;

        for (int i = 0; i < 26; i++)
        {
            table['a' + i] = 10 + i;
            table['A' + i] = 10 + i;
        }

        return table;
    }

    private static int[] CreateBase29Table()
    {
        int[] table = new int[128];
        for (int i = 0; i < table.Length; i++)
            table[i] = -1;

        for (int i = 0; i < Base29Characters.Length; i++)
            table[Base29Characters[i]] = i;

        return table;
    }



    public override void _Ready()
    {
        global_values = GetNode("/root/GlobalValues");
        // int i = 10;
        // for (int i = 0; i < 100; i++)
        //     GD.Print("Conversion Testing: " + BigIntegerToBase36(i, 448000));
        
    }



    // Public APIs

    public static GDictionary GetPageAndTitleString(GDictionary address)
    {
        int pageSize  = (int)global_values.Get("LINES") * (int)global_values.Get("WORDS");
        int totalSize = pageSize * (int)global_values.Get("PAGES");

        BigInteger bookValue = AddressToBookNumber(address);
        BigInteger titleValue;

        titleValue = ExtractRegion(bookValue, totalSize);
        bookValue = ExtractRegion(bookValue, totalSize - ((int)address["page"] + 1) * pageSize);

        string bookString  = BigIntegerToBase29(bookValue, pageSize);
        string titleString = BigIntegerToBase29(titleValue);

        BenchmarkTime("Extracted page and title.");

        return new GDictionary
        {
            {"title" , titleString},
            {"book" , bookString}
        };
    }



    public static GDictionary SearchEmptyPageRandomBook(string searchText)
    {
        int pageSize   = (int)global_values.Get("LINES") * (int)global_values.Get("WORDS");
        int totalPages = (int)global_values.Get("PAGES");
        int totalSize  = pageSize * totalPages;

        // The search text must fit within one page. If it's too long, we can't
        // place it — throw early with a clear message.
        if (searchText.Length > pageSize)
            throw new ArgumentException(
                $"Search text is {searchText.Length} characters, " +
                $"but a page is only {pageSize} characters.");

        // Step 1: Create the required page string.
        // We want:  [spaces][searchText][spaces]
        int textLength = searchText.Length;
        int maxLeftPad = pageSize - textLength;
        int leftPad    = Rng.Next(0, maxLeftPad + 1);   // inclusive on both ends
        int rightPad   = pageSize - textLength - leftPad;

        // Build the page as a char array.
        char[] pageChars = new char[pageSize];

        for (int i = 0; i < leftPad; i++)
            pageChars[i] = ' ';

        for (int i = 0; i < textLength; i++)
            pageChars[leftPad + i] = searchText[i];

        for (int i = 0; i < rightPad; i++)
            pageChars[leftPad + textLength + i] = ' ';

        string pageString = new string(pageChars);

        // Step 2: Convert the page string to a BigInteger.
        BigInteger pageNumber = Base29ToBigInteger(pageString.AsSpan());

        BenchmarkTime("Converted page text to BigInteger.");

        // Step 3: Choose a random target page index.
        int    targetPage      = Rng.Next(0, totalPages);
        int    offsetFromRight = (totalPages - targetPage - 1) * pageSize;

        // Step 4: Generate random noise for pages below the target.
        BigInteger bottomNoise = BigInteger.Zero;
        if (offsetFromRight > 0)
        {
            BigInteger bottomRange = BigInteger.Pow(29, offsetFromRight);
            bottomNoise = RandomBigInteger(bottomRange);
        }

        BenchmarkTime("Generated bottom noise.");

        // Step 5: Generate random noise for pages above the target.
        int    pagesAbove  = targetPage;
        int    topWidth    = (pagesAbove * pageSize) + (int)global_values.Get("TITLE");  // in base-29 digits

        BigInteger topNoise = BigInteger.Zero;
        if (topWidth > 0)
        {
            BigInteger topRange = BigInteger.Pow(29, topWidth);
            topNoise = RandomBigInteger(topRange);
        }

        BenchmarkTime("Generated top noise.");

        // Step 6: Combine everything into a single book number.
        // We add the numbers by multiplying them by the appropriate powers of 29 to shift them into place, then summing:
        BigInteger pageShift = BigInteger.Pow(29, offsetFromRight);
        BigInteger topShift  = BigInteger.Pow(29, offsetFromRight + pageSize);

        BigInteger bookNumber = (topNoise * topShift)
                              + (pageNumber * pageShift)
                              + bottomNoise;

        BenchmarkTime("Assembled book number.");

        // Step 7: Convert the book number into an address.
        GDictionary result = BookNumberToAddress(bookNumber);
        result["page"] = targetPage;

        BenchmarkTime("Converted book number to address.");

        return result;
    }



    // Helper methods

    private static BigInteger ExtractRegion(BigInteger value, int offsetFromRight)
    {
        BigInteger shifted = value / BigInteger.Pow(29, offsetFromRight);

        return shifted;
    }



    private static BigInteger RandomBigInteger(BigInteger exclusiveMax)
    {
        if (exclusiveMax <= 0)
            return BigInteger.Zero;

        byte[] maxBytes = exclusiveMax.ToByteArray();
        int    byteCount = maxBytes.Length;

        // Fill with random bytes.
        byte[] randomBytes = new byte[byteCount + 1];
        Rng.NextBytes(randomBytes);
        randomBytes[byteCount] = 0x00; // force positive

        BigInteger result = new BigInteger(randomBytes);

        // Clamp to [0, exclusiveMax).
        return result % exclusiveMax;
    }



    private static string RemoveLeadingZeros(string input)
    {
        int i = 0;
        while (i < input.Length && input[i] == '0')
            i++;

        return input.Substring(i);
    }


    // Core conversion methods

    private static GDictionary BookNumberToAddress(BigInteger bookNumber)
    {
        int BOOKS   = (int)global_values.Get("BOOKS");
        int SHELVES = (int)global_values.Get("SHELVES");
        int WALLS   = (int)global_values.Get("WALLS");
        int PAGES   = (int)global_values.Get("PAGES");
        int WORDS   = (int)global_values.Get("WORDS");
        int LINES   = (int)global_values.Get("LINES");

        bookNumber = BigInteger.DivRem(bookNumber, BOOKS,   out BigInteger bookRemainder);
        bookNumber = BigInteger.DivRem(bookNumber, SHELVES, out BigInteger shelfRemainder);
        bookNumber = BigInteger.DivRem(bookNumber, WALLS,   out BigInteger wallRemainder);

        BigInteger hexValue = bookNumber;

        int bookIndex  = (int)bookRemainder;
        int shelfIndex = (int)shelfRemainder;
        int wallIndex  = (int)wallRemainder;

        string hexString = RemoveLeadingZeros(BigIntegerToBase36(hexValue, PAGES * WORDS * LINES));

        BenchmarkTime("Unpacked address.");

        GD.Print("Wall: " + wallIndex + ", Shelf: " + shelfIndex + ", Book: " + bookIndex);

        return new GDictionary
        {
            {"hex", hexString},
            {"wall", wallIndex},
            {"shelf", shelfIndex},
            {"book", bookIndex},
            {"page", 0}
        };
    }



    private static BigInteger AddressToBookNumber(GDictionary address)
    {

        string bookKey = $"{address["hex"]}|{address["wall"]}|{address["shelf"]}|{address["book"]}";
        if (bookKey == cachedBookKey)
        {
            BenchmarkTime("Book value retrieved from cache (skipped recalculation).");
            return cachedBookValue;
        }

        BigInteger hexValue;
        if ((string)address["hex"] == cachedHex)
        {
            hexValue = cachedHexValue;
            BenchmarkTime("Hex retrieved from cache (skipped re-parsing).");
        }
        else
        {
            hexValue       = Base36ToBigInteger((string)address["hex"]);
            cachedHex      = (string)address["hex"];
            cachedHexValue = hexValue;
        }

        BigInteger bookValue = hexValue * (int)global_values.Get("WALLS") * (int)global_values.Get("SHELVES") * (int)global_values.Get("BOOKS")
                             + (int)address["wall"] * (int)global_values.Get("SHELVES") * (int)global_values.Get("BOOKS")
                             + (int)address["shelf"] * (int)global_values.Get("BOOKS")
                             + (int)address["book"];
                             
        cachedBookKey   = bookKey;
        cachedBookValue = bookValue;

        BenchmarkTime("Calculated book value.");

        return bookValue;
    }



    private static string BigIntegerToBase36(BigInteger value, int d)
    {
        if (d <= 1)
        {
            return BigIntegerToBase36Naive(value);
        }

        int k = d/2;

        BigInteger splitPoint = BigInteger.Pow(36, k);

        BigInteger high = value / splitPoint;
        BigInteger low  = value % splitPoint;

        string highStr = BigIntegerToBase36(high, d - k);
        string lowStr  = BigIntegerToBase36(low, k);
        
        lowStr = lowStr.PadLeft(k, '0');

        return highStr + lowStr;
    }



    private static string BigIntegerToBase36Naive(BigInteger value)
    {
        const string Base36Chars = "0123456789abcdefghijklmnopqrstuvwxyz";

        if (value == BigInteger.Zero)
            return "0";

        List<char> digits = new List<char>();
        while (value > 0)
        {
            value = BigInteger.DivRem(value, 36, out BigInteger remainder);
            digits.Add(Base36Chars[(int)remainder]);
        }

        digits.Reverse();
        return new string(digits.ToArray());
    }



    private static BigInteger Base36ToBigInteger(string value)
    {
        BigInteger result = 0;

        ReadOnlySpan<char> input = value.AsSpan();

        foreach (char c in input)
        {
            int digit = Base36Table[c];

            if (digit == -1)
                throw new ArgumentException($"Invalid character '{c}' in hex string.");

            result = result * 36 + digit;
        }

        BenchmarkTime("Converted from base-36.");

        return result;
    }



    private static string BigIntegerToBase29(BigInteger value, int stringLength = -1)
    {
        if (stringLength != -1)
        {
            char[] result = new char[stringLength];
            for (int i = stringLength - 1; i >= 0; i--)
            {
                value = BigInteger.DivRem(value,  29, out BigInteger remainder);
                result[i] = Base29Characters[(int)remainder];
            }
            return new string(result);
        }
        else
        {
            List<char> result = new List<char>();
            do
            {
                value = BigInteger.DivRem(value, 29, out BigInteger remainder);
                result.Add(Base29Characters[(int)remainder]);
            } while (value > 0);

            result.Reverse();
            return new string(result.ToArray());
        }
    }



    private static BigInteger Base29ToBigInteger(ReadOnlySpan<char> input)
    {
        if (input.Length <= 64)
        {
            BigInteger result = 0;

            foreach (char c in input)
            {
                int digit = Base29Table[c];

                if (digit == -1)
                    throw new ArgumentException($"Invalid character '{c}' in base-29 string.");

                result = result * 29 + digit;
            }

            return result;
        }

            int k = input.Length / 2;

            ReadOnlySpan<char> highPart = input.Slice(0, input.Length - k);
            ReadOnlySpan<char> lowPart  = input.Slice(input.Length - k, k);

            BigInteger Left = Base29ToBigInteger(highPart.ToString());
            BigInteger Right = Base29ToBigInteger(lowPart.ToString());
    
            BenchmarkTime("Converted from base-29 (optimized for short strings).");

            return (Left * Pow29(k)) + Right;
    }


    private static BigInteger Pow29(int y)
    {
        if (y == 0)
            return BigInteger.One;
        else if (y == 1)
            return new BigInteger(29);

        if (pow29Cache.TryGetValue(y, out BigInteger cached))
        {
            return cached;
        }

        int half = y / 2;

        BigInteger result = Pow29(half) * Pow29(y - half);

        pow29Cache[y] = result;
        
        return result;
    }

        // BigInteger result = 0;
        // ReadOnlySpan<char> input = value.AsSpan();

        // foreach (char c in input)
        // {
        //     int digit = Base29Table[c];

        //     if (digit == -1)
        //         throw new ArgumentException($"Invalid character '{c}' in base-29 string.");

        //     result = result * 29 + digit;
        // }

        // BenchmarkTime("Converted from base-29.");

        // return result;
    



    // Benchmarking

    private static void BenchmarkTime(string message)
    {
        ulong currentTime = Time.GetTicksMsec();
        ulong debugTime   = (ulong)global_values.Get("debug_time");

        GD.Print(((currentTime - debugTime) / 1000.0).ToString("F3") + "s — " + message);

        global_values.Set("debug_time", (long)currentTime);
    }
}