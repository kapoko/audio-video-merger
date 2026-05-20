import domReady from './helpers/domReady';

import { library, dom } from "@fortawesome/fontawesome-svg-core";
import { faGithub, faWindows, faApple, faPaypal} from "@fortawesome/free-brands-svg-icons";
import { faScaleBalanced, faLayerGroup } from "@fortawesome/free-solid-svg-icons";

library.add(faWindows, faApple, faGithub, faPaypal, faScaleBalanced, faLayerGroup);
dom.watch();

domReady(() => {
    // Nothing yet
});
