import { expect } from 'chai';
import { getSeconds } from "../src/lib/helpers";

describe('getSeconds helper', () => {
    it('should return false on invalid durationStrings', () => {
        expect(getSeconds('notADurationString')).to.equal(false);
        expect(getSeconds('01:01:11')).to.equal(false);
        expect(getSeconds('01:01:11.0')).to.equal(false);
    })

    it('should return correct number of seconds', () => {
        expect(getSeconds('00:01:33.99')).to.equal(93);
        expect(getSeconds('01:02:34.01')).to.equal(3754);
        expect(getSeconds('11:13:56.49')).to.equal(40436);
    });
});