/**
 * Converts a duration string (e.g. 01:35:33.40) to number of seconds
 * Returns false if duration string is not valid
 */
export function getSeconds(durationString:string): number | false {
    const pattern = /^(\d\d):(\d\d):(\d\d).\d\d$/;
    const m = pattern.exec(durationString);

    if (!m) {
        return false;
    }

    return parseInt(m[1]) * 60 * 60 + parseInt(m[2]) * 60 + parseInt(m[3]);
}

/**
 * Gets a basename including extension from path
 * @param str Full Path
 */
export function baseName(str: string): string
{
    const base = str.substring(str.lastIndexOf('/') + 1); 
    return base;
}