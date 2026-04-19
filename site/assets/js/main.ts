import domReady from './helpers/domReady';

import { library, dom } from "@fortawesome/fontawesome-svg-core";
import { faGithub, faWindows, faApple, faPaypal} from "@fortawesome/free-brands-svg-icons";
import {} from "@fortawesome/free-solid-svg-icons";

import '../sass/main.scss';

library.add(faWindows, faApple, faGithub, faPaypal);
dom.watch();

domReady(() => {
    // Nothing yet
});