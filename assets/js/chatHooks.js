export const ChatInput = {
    mounted() {
        this.el.addEventListener("keydown", (e) => {
            if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();

                document.querySelector("form").dispatchEvent(new Event("submit", {
                    bubbles: true,
                    cancelable: true
                }));
            }
        });
    }
}

/**
 * ChatList provides auto scrolling to the bottom of the list
 * Taken from https://github.com/elixirschool/live-view-chat/blob/master/assets/js/app.js#L22
 */
export const ChatList = {
    mounted() {
        // Select the node that will be observed for mutations
        const targetNode = this.el;

        document.addEventListener("DOMContentLoaded", function () {
            targetNode.scrollTop = targetNode.scrollHeight
        });

        // Options for the observer (which mutations to observe)
        const config = { attributes: true, childList: true, subtree: true };
        // Callback function to execute when mutations are observed
        const callback = function (mutationsList, observer) {
            for (const mutation of mutationsList) {
                if (mutation.type == 'childList') {
                    targetNode.scrollTop = targetNode.scrollHeight
                }
            }
        };
        // Create an observer instance linked to the callback function
        const observer = new MutationObserver(callback);
        // Start observing the target node for configured mutations
        observer.observe(targetNode, config);
    }
}