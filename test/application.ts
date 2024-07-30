import * as path from 'path';
import electron from "electron";

import anyTest, { TestInterface } from 'ava';
import { Application } from 'spectron';

const test = anyTest as TestInterface<{app: Application}>;

// test.beforeEach(async t => {
//     t.context.app = new Application({
//         args: [path.join(__dirname, '..')],
//         path: '' + electron,
//     });

//     await t.context.app.start();
// });

// test.afterEach.always(async t => {
//     console.log('stop');
//     await t.context.app.stop();
// });

test('Application opens window', async t => {
    const app = t.context.app;
    await app.client.waitUntilWindowLoaded();

    const win = app.browserWindow;
    t.is(await app.client.getWindowCount(), 1);
    t.false(await win.isMinimized());
    t.true(await win.isVisible());
    t.true(await win.isFocused());
  
    const {width, height} = await win.getBounds();
    t.true(width > 0);
    t.true(height > 0);
});

test.only('Spectron does not work for now with contextIsolation set to true', t => {
    t.true(true);
});
