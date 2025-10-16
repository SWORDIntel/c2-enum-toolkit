# Takeover & Handover Procedure

## WARNING: FOR AUTHORIZED USE ONLY

This document outlines the procedure for using the "Takeover/Handover" feature of the C2 Enumeration Toolkit. This feature is **not an offensive tool**. It is an evidence acquisition and packaging utility designed to prepare a comprehensive, legally-admissible data package for handover to law enforcement or other appropriate authorities.

**Misuse of this tool can have serious legal consequences.**

---

## 1. Purpose

The primary purpose of the Takeover/Handover feature is to:
- **Preserve evidence:** Create an immutable, verifiable snapshot of all collected intelligence on a target C2 server.
- **Ensure integrity:** Generate a chain of custody manifest with SHA256 hashes for all included files.
- **Provide context:** Create a human-readable summary report and a detailed, legally-focused log of all actions taken during the packaging process.
- **Standardize handover:** Produce a single, compressed archive (`.tar.gz`) that can be securely transferred to the relevant authorities.

---

## 2. The Process

The Takeover/Handover process is initiated from the main TUI and performs the following steps automatically:

1.  **Operator Verification:** The user is required to enter an **Operator ID**. This ID is logged with every action to maintain a clear record of who initiated the process. This is a critical step for accountability.

2.  **Target Selection:** The user selects a completed scan directory (e.g., `intel_...` or `comprehensive_scan_...`). This directory contains all the raw data that will be packaged.

3.  **Evidence Aggregation:**
    *   A temporary, timestamped directory is created (e.g., `takeover_<target>_<timestamp>`).
    *   All data from the selected scan directory is copied into this new directory.

4.  **Legal Logging:**
    *   A structured JSON log file (`evidence_log.json`) is created.
    *   Every step of the takeover process, from initiation to cleanup, is recorded as a separate, timestamped entry in this log. Each entry includes the Operator ID, the action performed, and a cryptographic hash to ensure its integrity.

5.  **Report Generation:**
    *   A `summary_report.md` is generated, providing a high-level overview of the C2 server's key intelligence metrics (e.g., open ports, discovered paths, binaries found).
    *   A `chain_of_custody.txt` manifest is created, listing every file in the package along with its SHA256 hash. This allows the receiving party to verify that the evidence has not been tampered with.

6.  **Packaging:**
    *   All contents of the temporary directory (raw data, logs, reports) are compressed into a single `takeover_package_<target>_<timestamp>.tar.gz` archive.
    *   The hash of the final archive is logged.

7.  **Finalization & Cleanup:**
    *   The temporary directory is deleted.
    *   The final package (`.tar.gz`) and the `evidence_log.json` are placed in a final, timestamped directory (e.g., `final_package_<target>_<timestamp>`).

---

## 3. How to Use

1.  From the main TUI menu, select option `[T] Initiate Takeover/Handover`.
2.  Read the legal disclaimer carefully.
3.  When prompted, enter your unique **Operator ID**. This is non-optional. Pressing Enter without an ID will cancel the process.
4.  From the list of available scan directories, select the one you wish to package for handover.
5.  The script will execute automatically. Monitor the output for any errors.
6.  Once complete, the final package and log will be located in a `final_package_*` directory in your current working directory.

---

## 4. Legal & Ethical Considerations

- **Authorization:** Do not initiate this process unless you are fully authorized to do so as part of a sanctioned investigation or defensive operation.
- **Data Handling:** The generated package contains sensitive intelligence and potential malware artifacts. Handle it according to your organization's data security policies.
- **Chain of Custody:** The `chain_of_custody.txt` is crucial. When handing over the package, provide this file separately or instruct the receiving party on how to use it to verify the integrity of the archive's contents.
- **Logging:** The `evidence_log.json` is your record of actions. It is designed to be admissible in legal proceedings. Do not modify it.

This feature transforms raw intelligence into a defensible evidence package. Treat it with the seriousness it requires.