import React, { useCallback, useEffect, useRef } from 'react';

/**
 * A horizontal drag handle placed between two vertically stacked panels.
 * Props:
 *   onResize(deltaY)  – called continuously while dragging with the pixel delta
 */
export default function ResizeHandle({ onResize }) {
  const dragging = useRef(false);
  const lastY = useRef(0);

  const onMouseDown = useCallback((e) => {
    e.preventDefault();
    dragging.current = true;
    lastY.current = e.clientY;
    document.body.style.cursor = 'row-resize';
    document.body.style.userSelect = 'none';
  }, []);

  useEffect(() => {
    const onMouseMove = (e) => {
      if (!dragging.current) return;
      const delta = e.clientY - lastY.current;
      lastY.current = e.clientY;
      onResize(delta);
    };

    const onMouseUp = () => {
      if (!dragging.current) return;
      dragging.current = false;
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);
    return () => {
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };
  }, [onResize]);

  return (
    <div
      className="resize-handle"
      onMouseDown={onMouseDown}
    >
      <div className="resize-handle-grip">
        <span /><span /><span />
      </div>
    </div>
  );
}
