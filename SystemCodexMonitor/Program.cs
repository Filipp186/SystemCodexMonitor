// Copyright (c) Microsoft Corporation
// The Microsoft Corporation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

using Microsoft.CommandPalette.Extensions;
using Shmuelie.WinRTServer;
using Shmuelie.WinRTServer.CsWinRT;
using System;
using System.Threading;

namespace SystemCodexMonitor;

public class Program
{
    [MTAThread]
    public static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--self-test")
        {
            RunSelfTest();
        }
        else if (args.Length > 0 && args[0] == "-RegisterProcessAsComServer")
        {
            global::Shmuelie.WinRTServer.ComServer server = new();

            ManualResetEvent extensionDisposedEvent = new(false);

            // Return the same extension instance for every COM activation.
            SystemCodexMonitor extensionInstance = new(extensionDisposedEvent);
            server.RegisterClass<SystemCodexMonitor, IExtension>(() => extensionInstance);
            server.Start();

            // This will make the main thread wait until the event is signalled by the extension class.
            // Since we have single instance of the extension object, we exit as soon as it is disposed.
            extensionDisposedEvent.WaitOne();
            server.Stop();
            server.UnsafeDispose();
        }
        else
        {
            Console.WriteLine("Not being launched as a Extension... exiting.");
        }
    }

    private static void RunSelfTest()
    {
        using var hardware = new HardwareMonitorService();
        using var codex = new CodexRateLimitService();
        Thread.Sleep(TimeSpan.FromSeconds(4));
        Console.WriteLine($"Hardware={hardware.Snapshot}; Codex={codex.Snapshot}");
    }
}
