# PsExec

PsExec is a small PowerShell module designed to make it easier to use Sysinternals' PsExec.exe within PowerShell.

**By using this module ("PsExec"), you agree to the [Sysinternals Software License Terms](https://technet.microsoft.com/en-us/sysinternals/bb469936) in addition to the license for this product.**

## Overview

There are currently only two functions in this module:

* **Get-PsExec** - Helper function to download PsExec.exe to a location on your machine.
* **Invoke-PsExec** - The "meat" of the module; this invokes PsExec on a local or remote computer.

## FAQs

### This seems like a really small module!

It is.

This is a need that I have in a lot of projects, and I was tired of making fixes in one project, then forgetting to copy them to another. I decided that even a small module would be a much easier way to allow other projects to reference the same function.

### Why should I use this module? So and so did PsExec through PowerShell much better!

I don't claim this is the first - or the best - implementation of PsExec in PowerShell. What I will say is that I couldn't find an existing implementation that met my needs exactly - either they were too complex, too simple, or didn't return all the data I needed.

Besides, as an open-source project, if something doesn't work the way you want it to work, feel free to change it! You can even submit an issue or a pull request so others can benefit from your changes as well.

## Acknowledgements

A lot of the continuous integration pieces of this module come from the great work RamblingCookieMonster has done in that space - the AppVeyor setup and many of the modules used in that process were written by him.