import ballerina/io;

const string ANSI_RESET = "\u{001b}[0m";
const string ANSI_BLUE = "\u{001b}[34m";
const string ANSI_GREEN = "\u{001b}[32m";
const string ANSI_RED = "\u{001b}[31m";
const string ANSI_YELLOW = "\u{001b}[33m";

function printHeading(string heading) {
    io:println(string `\n${ANSI_BLUE}=== ${heading} ===${ANSI_RESET}`);
}

function printSuccess(string message) {
    io:println(string `${ANSI_GREEN}${message}${ANSI_RESET}`);
}

function printWarning(string message) {
    io:println(string `${ANSI_YELLOW}${message}${ANSI_RESET}`);
}

function printFailure(string message) {
    io:println(string `${ANSI_RED}${message}${ANSI_RESET}`);
}

function renderResult(json|error result, string successMessage = "Request completed") {
    if result is error {
        printFailure(result.message());
        return;
    }
    printSuccess(successMessage);
    if result is json[] {
        if result.length() == 0 {
            io:println("No records found.");
            return;
        }
        int position = 1;
        foreach json item in result {
            io:println(string `  ${position}. ${item.toJsonString()}`);
            position += 1;
        }
        return;
    }
    io:println(result.toJsonString());
}

function readRequired(string prompt) returns string {
    while true {
        string value = io:readln(prompt).trim();
        if value != "" {
            return value;
        }
        printWarning("A value is required.");
    }
}

function readWithDefault(string prompt, string defaultValue) returns string {
    string value = io:readln(string `${prompt} [${defaultValue}]: `).trim();
    return value == "" ? defaultValue : value;
}

function readIntValue(string prompt, int minimum = 0) returns int {
    while true {
        int|error parsedValue = int:fromString(io:readln(prompt).trim());
        if parsedValue is int && parsedValue >= minimum {
            return parsedValue;
        }
        printWarning(string `Enter a whole number greater than or equal to ${minimum}.`);
    }
}

function readDecimalValue(string prompt, decimal minimum = 0d) returns decimal {
    while true {
        decimal|error parsedValue = decimal:fromString(io:readln(prompt).trim());
        if parsedValue is decimal && parsedValue >= minimum {
            return parsedValue;
        }
        printWarning(string `Enter a number greater than or equal to ${minimum}.`);
    }
}

function readBooleanValue(string prompt, boolean defaultValue = true) returns boolean {
    string defaultLabel = defaultValue ? "Y" : "N";
    while true {
        string value = io:readln(string `${prompt} [${defaultLabel}]: `).trim().toUpperAscii();
        if value == "" {
            return defaultValue;
        }
        if value == "Y" || value == "YES" {
            return true;
        }
        if value == "N" || value == "NO" {
            return false;
        }
        printWarning("Enter Y or N.");
    }
}

function readOptional(string prompt) returns string? {
    string value = io:readln(prompt).trim();
    return value == "" ? () : value;
}

function pauseForUser() {
    _ = io:readln("\nPress Enter to continue...");
}
