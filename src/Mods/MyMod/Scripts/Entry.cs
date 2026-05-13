using HarmonyLib;
using System.Reflection;

// Import the Harmony library for patching game code
using HarmonyLib;
using System.Reflection;

// This class is the entry point for your mod's DLL.
// It must implement IModApi so the game can call it when loading your mod.
public class Entry : IModApi
{
    // This will hold our Harmony instance, which manages all our patches.
    private static Harmony _harmony;

    // This method is called by the game when your mod loads.
    // 'modInstance' is a reference to your mod's metadata and files.
    public void InitMod(Mod modInstance)
    {
        // Create a new Harmony instance with a unique ID (change this to your own domain/mod name!)
        _harmony = new Harmony("com.example.mymod");

        // Apply all Harmony patches in this DLL (searches for classes/methods with [HarmonyPatch] attributes)
        _harmony.PatchAll(Assembly.GetExecutingAssembly());

        // Print a message to the server console so you know your mod loaded and patches ran
        System.Console.WriteLine("[MyMod] Harmony patches loaded!");
    }

    // This is a static method you can call from anywhere in your mod to print a test message.
    // It does NOT run automatically—call Entry.OutputTestMessage() yourself to see it in the console.
    public static void OutputTestMessage()
    {
        System.Console.WriteLine("[MyMod] This is a test message from the mod DLL.");
    }
}
