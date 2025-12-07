// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/todos"
import topbar from "../vendor/topbar"
import Sortable from "sortablejs"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Custom hooks
const Hooks = {
  // Plan canvas hook for pan/zoom functionality
  PlanCanvas: {
    mounted() {
      this.state = {
        viewportX: parseFloat(this.el.dataset.viewportX) || 0,
        viewportY: parseFloat(this.el.dataset.viewportY) || 0,
        zoom: parseFloat(this.el.dataset.zoom) || 1,
        isPanning: false,
        startX: 0,
        startY: 0,
        startViewportX: 0,
        startViewportY: 0
      }

      this.controller = this.el.querySelector("[data-canvas-controller]")
      this.grid = this.el.querySelector("#canvas-grid")
      this.saveTimeout = null

      // Pan via mouse drag on empty canvas space
      this.el.addEventListener("mousedown", this.onMouseDown.bind(this))
      window.addEventListener("mousemove", this.onMouseMove.bind(this))
      window.addEventListener("mouseup", this.onMouseUp.bind(this))

      // Zoom via scroll wheel
      this.el.addEventListener("wheel", this.onWheel.bind(this), { passive: false })

      // Touch support for mobile
      this.el.addEventListener("touchstart", this.onTouchStart.bind(this), { passive: false })
      this.el.addEventListener("touchmove", this.onTouchMove.bind(this), { passive: false })
      this.el.addEventListener("touchend", this.onTouchEnd.bind(this))

      // ESC to cancel connection mode
      window.addEventListener("keydown", this.onKeyDown.bind(this))

      this.updateTransform()
    },

    destroyed() {
      window.removeEventListener("mousemove", this.onMouseMove.bind(this))
      window.removeEventListener("mouseup", this.onMouseUp.bind(this))
      window.removeEventListener("keydown", this.onKeyDown.bind(this))
    },

    onMouseDown(event) {
      // Only pan if clicking on empty canvas (not on cards or buttons)
      const target = event.target
      if (target.closest("[data-card-id]") || 
          target.closest("button") || 
          target.closest("[data-connection-source]") ||
          target.closest("[data-connection-target]")) {
        return
      }

      this.state.isPanning = true
      this.state.startX = event.clientX
      this.state.startY = event.clientY
      this.state.startViewportX = this.state.viewportX
      this.state.startViewportY = this.state.viewportY
      this.el.style.cursor = "grabbing"
    },

    onMouseMove(event) {
      if (!this.state.isPanning) return

      const dx = event.clientX - this.state.startX
      const dy = event.clientY - this.state.startY

      this.state.viewportX = this.state.startViewportX + dx
      this.state.viewportY = this.state.startViewportY + dy

      this.updateTransform()
    },

    onMouseUp() {
      if (this.state.isPanning) {
        this.state.isPanning = false
        this.el.style.cursor = "grab"
        this.debounceSaveViewport()
      }
    },

    onWheel(event) {
      event.preventDefault()

      const isZoom = event.ctrlKey || event.metaKey

      if (isZoom) {
        // Zoom centered on mouse position
        const rect = this.el.getBoundingClientRect()
        const mouseX = event.clientX - rect.left
        const mouseY = event.clientY - rect.top

        const oldZoom = this.state.zoom
        const delta = event.deltaY < 0 ? 0.1 : -0.1
        const newZoom = Math.max(0.25, Math.min(2, oldZoom + delta))

        // Adjust viewport to zoom toward mouse position
        const zoomRatio = newZoom / oldZoom
        this.state.viewportX = mouseX - (mouseX - this.state.viewportX) * zoomRatio
        this.state.viewportY = mouseY - (mouseY - this.state.viewportY) * zoomRatio
        this.state.zoom = newZoom
      } else {
        // Pan
        this.state.viewportX -= event.deltaX
        this.state.viewportY -= event.deltaY
      }

      this.updateTransform()
      this.debounceSaveViewport()
    },

    onTouchStart(event) {
      if (event.touches.length === 1) {
        const touch = event.touches[0]
        const target = touch.target
        
        if (target.closest("[data-card-id]") || target.closest("button")) {
          return
        }

        this.state.isPanning = true
        this.state.startX = touch.clientX
        this.state.startY = touch.clientY
        this.state.startViewportX = this.state.viewportX
        this.state.startViewportY = this.state.viewportY
      }
    },

    onTouchMove(event) {
      if (!this.state.isPanning || event.touches.length !== 1) return
      event.preventDefault()

      const touch = event.touches[0]
      const dx = touch.clientX - this.state.startX
      const dy = touch.clientY - this.state.startY

      this.state.viewportX = this.state.startViewportX + dx
      this.state.viewportY = this.state.startViewportY + dy

      this.updateTransform()
    },

    onTouchEnd() {
      if (this.state.isPanning) {
        this.state.isPanning = false
        this.debounceSaveViewport()
      }
    },

    onKeyDown(event) {
      if (event.key === "Escape") {
        this.pushEvent("cancel-connection", {})
      }
    },

    updateTransform() {
      if (this.controller) {
        this.controller.style.transform = 
          `translate(${this.state.viewportX}px, ${this.state.viewportY}px) scale(${this.state.zoom})`
      }
      if (this.grid) {
        const gridSize = 40 * this.state.zoom
        this.grid.style.backgroundSize = `${gridSize}px ${gridSize}px`
        this.grid.style.backgroundPosition = `${this.state.viewportX}px ${this.state.viewportY}px`
      }
    },

    debounceSaveViewport() {
      if (this.saveTimeout) clearTimeout(this.saveTimeout)
      this.saveTimeout = setTimeout(() => {
        this.pushEvent("save-viewport", {
          x: this.state.viewportX,
          y: this.state.viewportY,
          zoom: this.state.zoom
        })
      }, 500)
    }
  },

  // Card drag hook
  PlanCard: {
    mounted() {
      this.cardId = this.el.dataset.cardId
      this.isDragging = false
      this.startX = 0
      this.startY = 0
      this.startLeft = 0
      this.startTop = 0

      // Get the draggable inner element (the card itself, not connection dots)
      const card = this.el.querySelector(".cursor-move")
      if (card) {
        card.addEventListener("mousedown", this.onMouseDown.bind(this))
      }

      window.addEventListener("mousemove", this.onMouseMove.bind(this))
      window.addEventListener("mouseup", this.onMouseUp.bind(this))

      // Touch support
      if (card) {
        card.addEventListener("touchstart", this.onTouchStart.bind(this), { passive: false })
      }
      window.addEventListener("touchmove", this.onTouchMove.bind(this), { passive: false })
      window.addEventListener("touchend", this.onTouchEnd.bind(this))
    },

    destroyed() {
      window.removeEventListener("mousemove", this.onMouseMove.bind(this))
      window.removeEventListener("mouseup", this.onMouseUp.bind(this))
      window.removeEventListener("touchmove", this.onTouchMove.bind(this))
      window.removeEventListener("touchend", this.onTouchEnd.bind(this))
    },

    onMouseDown(event) {
      // Don't drag if clicking on buttons or connection dots
      if (event.target.closest("button") || 
          event.target.closest("[data-connection-source]") ||
          event.target.closest("[data-connection-target]")) {
        return
      }

      event.stopPropagation()
      this.startDrag(event.clientX, event.clientY)
    },

    onTouchStart(event) {
      if (event.target.closest("button")) return
      if (event.touches.length !== 1) return

      event.preventDefault()
      event.stopPropagation()
      
      const touch = event.touches[0]
      this.startDrag(touch.clientX, touch.clientY)
    },

    startDrag(clientX, clientY) {
      this.isDragging = true
      this.startX = clientX
      this.startY = clientY
      this.startLeft = parseFloat(this.el.style.left) || 0
      this.startTop = parseFloat(this.el.style.top) || 0
      this.el.style.zIndex = "100"
    },

    onMouseMove(event) {
      if (!this.isDragging) return
      this.moveDrag(event.clientX, event.clientY)
    },

    onTouchMove(event) {
      if (!this.isDragging || event.touches.length !== 1) return
      event.preventDefault()
      
      const touch = event.touches[0]
      this.moveDrag(touch.clientX, touch.clientY)
    },

    moveDrag(clientX, clientY) {
      // Get the zoom level from the canvas controller
      const canvas = document.getElementById("plan-canvas")
      const zoom = parseFloat(canvas?.dataset.zoom) || 1

      const dx = (clientX - this.startX) / zoom
      const dy = (clientY - this.startY) / zoom

      const newLeft = this.startLeft + dx
      const newTop = this.startTop + dy

      this.el.style.left = `${newLeft}px`
      this.el.style.top = `${newTop}px`
    },

    onMouseUp() {
      this.endDrag()
    },

    onTouchEnd() {
      this.endDrag()
    },

    endDrag() {
      if (!this.isDragging) return

      this.isDragging = false
      this.el.style.zIndex = ""

      const x = parseFloat(this.el.style.left) || 0
      const y = parseFloat(this.el.style.top) || 0

      this.pushEvent("move-card", {
        id: this.cardId,
        x: x,
        y: y
      })
    }
  },

  SortableTags: {
    mounted() {
      new Sortable(this.el, {
        animation: 150,
        handle: "[data-drag-handle]",
        ghostClass: "opacity-50",
        onEnd: () => {
          const ids = [...this.el.children].map(el => el.dataset.tagId)
          this.pushEvent("reorder-tags", { tag_ids: ids })
        }
      })
    }
  },
  CoursesPrompt: {
    mounted() {
      this.el.addEventListener("click", () => {
        const title = prompt("Add to courses:");
        if (title && title.trim()) {
          this.pushEvent("add-courses-subtask", { title: title.trim() });
        }
      });
    }
  },
  Fullscreen: {
    mounted() {
      this.el.addEventListener("click", () => {
        if (!document.fullscreenElement) {
          document.documentElement.requestFullscreen().catch(err => {
            console.log("Fullscreen not supported:", err);
          });
          this.el.textContent = "[EXIT FS]";
        } else {
          document.exitFullscreen();
          this.el.textContent = "[FULLSCREEN]";
        }
      });

      document.addEventListener("fullscreenchange", () => {
        if (document.fullscreenElement) {
          this.el.textContent = "[EXIT FS]";
        } else {
          this.el.textContent = "[FULLSCREEN]";
        }
      });
    }
  },
  SaveIndicator: {
    mounted() {
      const status = this.el.querySelector("#save-status");
      let fadeTimeout = null;

      window.addEventListener("phx:saving", () => {
        if (fadeTimeout) clearTimeout(fadeTimeout);
        status.textContent = "[SAVING...]";
        status.className = "animate-pulse text-warning";
      });

      window.addEventListener("phx:saved", () => {
        if (fadeTimeout) clearTimeout(fadeTimeout);
        status.textContent = "[SAVED]";
        status.className = "text-success";

        fadeTimeout = setTimeout(() => {
          status.textContent = "";
          status.className = "";
        }, 2000);
      });

      window.addEventListener("phx:save-error", () => {
        if (fadeTimeout) clearTimeout(fadeTimeout);
        status.textContent = "[SAVE FAILED]";
        status.className = "text-error";
      });
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

