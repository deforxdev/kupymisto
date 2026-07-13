import { motion, useReducedMotion } from "framer-motion";

interface GameStartSplashProps {
  roomName: string;
  onComplete: () => void;
}

const countdown = [3, 2, 1];

export default function GameStartSplash({
  roomName,
  onComplete,
}: GameStartSplashProps) {
  const reducedMotion = useReducedMotion();

  return (
    <motion.section
      className="gameStartSplash"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, filter: reducedMotion ? "none" : "blur(10px)" }}
      transition={{ duration: reducedMotion ? 0.15 : 0.45 }}
      aria-label="Гра починається"
    >
      <div className="startWipes" aria-hidden="true">
        <motion.i
          initial={{ scaleX: 1 }}
          animate={{ scaleX: 0 }}
          transition={{ duration: 0.9, delay: 0.1, ease: [0.76, 0, 0.24, 1] }}
        />
        <motion.i
          initial={{ scaleX: 1 }}
          animate={{ scaleX: 0 }}
          transition={{ duration: 0.9, delay: 0.2, ease: [0.76, 0, 0.24, 1] }}
        />
        <motion.i
          initial={{ scaleX: 1 }}
          animate={{ scaleX: 0 }}
          transition={{ duration: 0.9, delay: 0.3, ease: [0.76, 0, 0.24, 1] }}
        />
      </div>

      <div className="startBoardMark" aria-hidden="true">
        {Array.from({ length: 16 }, (_, index) => (
          <i key={index} />
        ))}
        <motion.b
          initial={reducedMotion ? false : { x: -90, y: 55, opacity: 0 }}
          animate={{ x: 0, y: 0, opacity: 1 }}
          transition={{ duration: 2.7, ease: [0.16, 1, 0.3, 1] }}
        />
      </div>

      {!reducedMotion && (
        <div className="startNumberStage" aria-hidden="true">
          {countdown.map((number, index) => (
            <motion.span
              key={number}
              initial={{ opacity: 0, scale: 0.45, filter: "blur(12px)" }}
              animate={{
                opacity: [0, 1, 1, 0],
                scale: [0.45, 1, 1, 1.5],
                filter: ["blur(12px)", "blur(0px)", "blur(0px)", "blur(8px)"],
              }}
              transition={{
                duration: 0.82,
                delay: 0.35 + index * 0.72,
                times: [0, 0.22, 0.68, 1],
                ease: [0.16, 1, 0.3, 1],
              }}
            >
              {number}
            </motion.span>
          ))}
        </div>
      )}

      <motion.div
        className="startCopy startCopyFinal"
        initial={reducedMotion ? false : { opacity: 0, y: 28, scale: 0.9 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{
          duration: 0.72,
          delay: reducedMotion ? 0 : 2.62,
          ease: [0.16, 1, 0.3, 1],
        }}
      >
        <span>КупиМісто · 30 кіл</span>
        <h1>МІСТО В ГРІ</h1>
        <p>
          <strong>{roomName}</strong>Перший хід починається
        </p>
      </motion.div>

      <motion.button
        type="button"
        className="startSkip"
        onClick={onComplete}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{
          type: "spring",
          stiffness: 400,
          damping: 10,
          delay: reducedMotion ? 0 : 0.9,
        }}
        whileTap={{ scale: 0.96, y: 2 }}
      >
        Пропустити
      </motion.button>
    </motion.section>
  );
}
