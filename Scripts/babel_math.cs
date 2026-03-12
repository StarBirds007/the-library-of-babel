using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;


public partial class babel_math : Node
{
    const int WALLS = 4;
    const int SHELVES = 5;
    const int BOOKS = 32;
    const int PAGES = 140;
    const int LINES = 40;
    const int WORDS = 80;

    public static string GetPageString(string hex, int wall, int shelf, int book, int page)
    {
        return DecToBase29(GetPage(hex, wall, shelf, book, page));
    }

    public static BigInteger GetPage(string hex, int wall, int shelf, int book, int page)
    {
        BigInteger page_value = BigInteger.Parse(hex, System.Globalization.NumberStyles.HexNumber);
        page_value = page_value * WALLS + wall;
        page_value = page_value * SHELVES + shelf;
        page_value = page_value * BOOKS + book;
        page_value = page_value * PAGES + page;
        GD.Print("Calculated page value: " + page_value);

        return page_value;
    }

    public static string DecToBase29(BigInteger page)
    {
        string[] characters = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
        "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", " ", ",", "."};
        List<string> converted = new List<string>();

        do
        {
            page = BigInteger.DivRem(page, 29, out BigInteger remainder);
            converted.Add(characters[(int)remainder]);
        } while (page > 0);
        
        converted.Reverse();
        
        string output = string.Join("", converted);

        return output.PadLeft(LINES * WORDS, 'a');
    }
	
}
