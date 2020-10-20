import test from 'ava';
import { getSeconds, baseName } from "../src/lib/helpers";

test('getSeconds() should return false on invalid durationStrings', t => {
    t.false(getSeconds('notADurationString'));
    t.false(getSeconds('01:01:11'));
    t.false(getSeconds('01:01:11.0'));
});

test('getSeconds() should return correct number of seconds', t => {
    t.is(getSeconds('00:01:33.99'), 93);
    t.is(getSeconds('01:02:34.01'), 3754);
    t.is(getSeconds('11:13:56.49'), 40436);
});

test('baseName() should return filename with extension from path', t => {
    t.is(baseName('/path/to/file.js'), 'file.js');
});
