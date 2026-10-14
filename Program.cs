using System;
using System.IO;
using System.Reflection;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        bool verify = args.Length == 3 && args[0] == "--verify";
        bool verifyUi = args.Length == 2 && args[0] == "--verify-ui";
        try
        {
            string script;
            using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("ImageToIco.ps1"))
            using (StreamReader reader = new StreamReader(resource))
                script = reader.ReadToEnd();
            using (Runspace runspace = RunspaceFactory.CreateRunspace())
            using (PowerShell shell = PowerShell.Create())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                shell.Runspace = runspace;
                if (verifyUi)
                {
                    script = script.Replace("$null = $form.ShowDialog()",
                        "if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') { throw 'UI thread is not STA' }; " +
                        "$handle = $form.Handle; foreach ($control in $form.Controls) { $null = $control.Handle }; " +
                        "if (!$form.AllowDrop -or $handle -eq [IntPtr]::Zero) { throw 'DragDrop registration failed' }");
                }
                shell.AddScript(script);
                if (verify) shell.AddParameter("LibraryOnly", true);
                shell.Invoke();
                CheckErrors(shell);
                if (verifyUi)
                    File.WriteAllText(args[1], "PASS STA UI thread, window handles and DragDrop registration");
                if (verify)
                {
                    shell.Commands.Clear();
                    shell.AddCommand("ConvertTo-Ico")
                         .AddParameter("Source", Path.GetFullPath(args[1]))
                         .AddParameter("Destination", Path.GetFullPath(args[2]));
                    shell.Invoke();
                    CheckErrors(shell);
                    File.WriteAllText(args[2] + ".status.txt", "PASS embedded EXE conversion");
                }
            }
            return 0;
        }
        catch (Exception error)
        {
            if (verify) File.WriteAllText(args[2] + ".status.txt", "FAIL " + error);
            else if (verifyUi) File.WriteAllText(args[1], "FAIL " + error);
            else MessageBox.Show(error.Message, "轻图标启动失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static void CheckErrors(PowerShell shell)
    {
        if (shell.HadErrors)
            throw new InvalidOperationException(String.Join(Environment.NewLine, shell.Streams.Error));
    }
}
