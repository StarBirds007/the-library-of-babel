using Godot;
using GDictionary = Godot.Collections.Dictionary;
using System;
using System.Numerics;
using System.Collections.Generic;



public partial class babel_math : Node
{
    private static Node global_values;
    private static Dictionary<string, int> bookParameters = new Dictionary<string, int>();
    private static int pageSize;
    private static int totalSize;

    private static class LCG
    {
        public static BigInteger a;
        public static BigInteger c;
        public static BigInteger m;
        public static BigInteger a_inv;  // modular inverse of a mod m

        public static void BuildParameters(BigInteger min_m)
        {
            BigInteger a_minus_1 = min_m / 2;

            m = 4 * a_minus_1;
            a = a_minus_1 + 1;
            c =   //(BigInteger.Pow(2, 4253) - 1) *
                  //(BigInteger.Pow(2, 11213) - 1) *
                  //(BigInteger.Pow(2, 13466917) - 1) *
                  //8191 *
                13;

            a_inv = ModInverse(a, m);
        }

        public static BigInteger Scramble(BigInteger value, bool reverse = false)
        {
            // return value;
            if (reverse)
                return a_inv * (value - c % m + m) % m;
            else
                return (a * value + c) % m;
        }
    }
    private static class BitFlip
    {
        private static int totalBits;
        private static int offset;   // We set an offset to make sure the resulting value doesn't exceed 29^totalSize.
        private static int bitsToFlip;

        public static void BuildParameters(BigInteger maxValueExclusive, int offset, int bitsToFlip)
        {
            totalBits   = (int)maxValueExclusive.GetBitLength();
            BitFlip.offset = offset;
            BitFlip.bitsToFlip = bitsToFlip;
        }

        public static BigInteger Flip(BigInteger value)
        {
            BigInteger result = value;

            for (int i = 0; i < bitsToFlip; i++)
            {
                int highBitPos = totalBits - 1 - offset - i;
                int lowBitPos  = bitsToFlip - 1 - i;

                bool highBit = ((result >> highBitPos) & 1) == 1;
                bool lowBit  = ((result >> lowBitPos)  & 1) == 1;

                if (highBit != lowBit)
                {
                    result ^= (BigInteger.One << highBitPos);
                    result ^= (BigInteger.One << lowBitPos);
                }
            }

            return result;
        }
    }


    private static string     cachedHex      = "";
    private static BigInteger cachedHexValue = BigInteger.Zero;

    private static string     cachedBookKey   = "";
    private static BigInteger cachedBookValue = BigInteger.Zero;

    private static Dictionary<BigInteger, BigInteger> pow29Cache = new Dictionary<BigInteger, BigInteger>();
    private static Dictionary<BigInteger, BigInteger> pow36Cache = new Dictionary<BigInteger, BigInteger>();

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
        bookParameters["WALLS"] = (int)global_values.Get("WALLS");
        bookParameters["SHELVES"] = (int)global_values.Get("SHELVES");
        bookParameters["BOOKS"] = (int)global_values.Get("BOOKS");
        bookParameters["PAGES"] = (int)global_values.Get("PAGES");
        bookParameters["LINES"] = (int)global_values.Get("LINES");
        bookParameters["WORDS"] = (int)global_values.Get("WORDS");
        bookParameters["TITLE"] = (int)global_values.Get("TITLE");

        pageSize  = bookParameters["LINES"] * bookParameters["WORDS"];
        totalSize = (pageSize * bookParameters["PAGES"]) + bookParameters["TITLE"];

        LCG.BuildParameters(Pow29(totalSize));
        BitFlip.BuildParameters(Pow29(totalSize), offset: 5, bitsToFlip: 10);
    }



    // Public APIs

    public static GDictionary GetPageAndTitleString(GDictionary address)
    {
        BigInteger bookValue = AddressToBookNumber(address);   // This stores the entire numerical value of the book itself.
        BigInteger titleValue;

        BenchmarkTime("Calculated book value.");

        bookValue = LCG.Scramble(bookValue);
        bookValue = BitFlip.Flip(bookValue);

        BenchmarkTime("Scrambled and flipped book value.");

        // The ExtractRegion function extracts the "left side" of a numerical value from a given offset from the right.
        titleValue = ExtractRegion(bookValue, totalSize - bookParameters["TITLE"]);   // Removed the total size of the book (all 140 pages) from the right, which leaves the 30 letter title.
        bookValue = ExtractRegion(bookValue, totalSize - bookParameters["TITLE"] - ((int)address["page"] + 1) * pageSize);

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

        BenchmarkTime("Converted from base-29.");

        // Step 3: Choose a random target page index.
        int targetPage      = Rng.Next(0, bookParameters["PAGES"]);
        int offsetFromRight = (bookParameters["PAGES"] - targetPage - 1) * pageSize;

        // Step 4: Generate random noise for pages below the target.
        BigInteger bottomNoise = BigInteger.Zero;
        if (offsetFromRight > 0)
        {
            BigInteger bottomRange = BigInteger.Pow(29, offsetFromRight);
            bottomNoise = RandomBigInteger(bottomRange);
        }

        // Step 5: Generate random noise for pages above the target.
        int    pagesAbove  = targetPage;
        int    topWidth    = (pagesAbove * pageSize) + (int)global_values.Get("TITLE");  // in base-29 digits

        BigInteger topNoise = BigInteger.Zero;
        if (topWidth > 0)
        {
            BigInteger topRange = BigInteger.Pow(29, topWidth);
            topNoise = RandomBigInteger(topRange);
        }

        BenchmarkTime("Generated noise.");

        // Step 6: Combine everything into a single book number.
        // We add the numbers by multiplying them by the appropriate powers of 29 to shift them into place, then summing:
        BigInteger pageShift = BigInteger.Pow(29, offsetFromRight);
        BigInteger topShift  = BigInteger.Pow(29, offsetFromRight + pageSize);

        BigInteger bookNumber = (topNoise * topShift)
                              + (pageNumber * pageShift)
                              + bottomNoise;

        BenchmarkTime("Assembled book number.");

        // Step 7: Unscramble the book number with the LCG.
        bookNumber = BitFlip.Flip(bookNumber);
        bookNumber = LCG.Scramble(bookNumber, reverse: true);

        BenchmarkTime("Unscrambled and flipped book number.");

        // Step 8: Convert the book number into an address.
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



    private static (BigInteger gcd, BigInteger x, BigInteger y) ExtendedGcd(BigInteger a, BigInteger m)   // Returns (gcd, x, y) such that a*x + m*y = gcd

    {
        if (m == 0)
            return (a, 1, 0);

        var (gcd, x1, y1) = ExtendedGcd(m, a % m);

        BigInteger x = y1;
        BigInteger y = x1 - (a / m) * y1;

        return (gcd, x, y);
    }



    public static BigInteger ModInverse(BigInteger a, BigInteger m)
    {
        var (gcd, x, _) = ExtendedGcd(a, m);

        if (gcd != 1)
            throw new ArgumentException("a and m are not coprime — no inverse exists.");

        // x might be negative; force it into [0, m)
        return ((x % m) + m) % m;
    }



    private static BigInteger Pow29(BigInteger y)
    {
        if (y == 0)
            return BigInteger.One;
        else if (y == 1)
            return new BigInteger(29);

        if (pow29Cache.TryGetValue(y, out BigInteger cached))
        {
            return cached;
        }

        BigInteger half = y / 2;

        BigInteger result = Pow29(half) * Pow29(y - half);

        pow29Cache[y] = result;
        
        return result;
    }    



    private static BigInteger Pow36(BigInteger y)
    {
        if (y == 0)
            return BigInteger.One;
        else if (y == 1)
            return new BigInteger(36);

        if (pow36Cache.TryGetValue(y, out BigInteger cached))
        {
            return cached;
        }

        BigInteger half = y / 2;

        BigInteger result = Pow36(half) * Pow36(y - half);

        pow36Cache[y] = result;
        
        return result;
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

        BenchmarkTime("Converted from base-36.");


        BigInteger bookValue = hexValue * (int)global_values.Get("WALLS") * (int)global_values.Get("SHELVES") * (int)global_values.Get("BOOKS")
                             + (int)address["wall"] * (int)global_values.Get("SHELVES") * (int)global_values.Get("BOOKS")
                             + (int)address["shelf"] * (int)global_values.Get("BOOKS")
                             + (int)address["book"];
                             
        cachedBookKey   = bookKey;
        cachedBookValue = bookValue;

        return bookValue;
    }



    private static string BigIntegerToBase36(BigInteger value, int d)   // Uses recursion, also calls BigIntegerToBase36Naive.
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



    private static BigInteger Base36ToBigInteger(ReadOnlySpan<char> input)
    {
        if (input.Length <= 64)
        {
            BigInteger result = 0;

            foreach (char c in input)
            {
                int digit = Base36Table[c];

                if (digit == -1)
                    throw new ArgumentException($"Invalid character '{c}' in base-36 string.");

                result = result * 36 + digit;
            }

            return result;
        }

            int k = input.Length / 2;

            ReadOnlySpan<char> highPart = input.Slice(0, input.Length - k);
            ReadOnlySpan<char> lowPart  = input.Slice(input.Length - k, k);

            BigInteger Left = Base36ToBigInteger(highPart);
            BigInteger Right = Base36ToBigInteger(lowPart);
    
            return (Left * Pow36(k)) + Right;
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

            BigInteger Left = Base29ToBigInteger(highPart);
            BigInteger Right = Base29ToBigInteger(lowPart);
    
            return (Left * Pow29(k)) + Right;
    }



    // Benchmarking

    private static void BenchmarkTime(string message)
    {
        ulong currentTime = Time.GetTicksMsec();
        ulong debugTime   = (ulong)global_values.Get("debug_time");

        GD.Print(((currentTime - debugTime) / 1000.0).ToString("F3") + "s — " + message);

        global_values.Set("debug_time", (long)currentTime);
    }
}