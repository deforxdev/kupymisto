import { Canvas, useFrame } from '@react-three/fiber'
import { ContactShadows, Environment, Float, RoundedBox } from '@react-three/drei'
import { useRef } from 'react'
import type { Group, Mesh } from 'three'

const colors = {
  ink: '#20202a', paper: '#f2eee2', blue: '#3167dc', yellow: '#f2c84b',
  red: '#de5549', green: '#54b87a', orange: '#e98a44'
}

function House({ position, color, scale = 1 }: { position: [number, number, number], color: string, scale?: number }) {
  return (
    <group position={position} scale={scale}>
      <RoundedBox args={[0.7, 0.58, 0.7]} radius={0.06} smoothness={3} position={[0, 0.29, 0]}>
        <meshStandardMaterial color={color} roughness={0.62} />
      </RoundedBox>
      <mesh position={[0, 0.8, 0]} rotation={[0, Math.PI / 4, 0]}>
        <coneGeometry args={[0.62, 0.52, 4]} />
        <meshStandardMaterial color={colors.red} roughness={0.55} />
      </mesh>
      <mesh position={[0, 0.27, 0.356]}>
        <boxGeometry args={[0.2, 0.36, 0.02]} />
        <meshStandardMaterial color={colors.ink} />
      </mesh>
    </group>
  )
}

function Coin({ position, color = colors.yellow, speed = 1 }: { position: [number, number, number], color?: string, speed?: number }) {
  const ref = useRef<Mesh>(null)
  useFrame((state, delta) => {
    if (!ref.current) return
    ref.current.rotation.y += delta * speed
    ref.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * speed) * 0.16
  })
  return (
    <mesh ref={ref} position={position} rotation={[Math.PI / 2, 0, 0]}>
      <cylinderGeometry args={[0.43, 0.43, 0.12, 48]} />
      <meshStandardMaterial color={color} metalness={0.18} roughness={0.32} />
      <mesh position={[0, 0.071, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.29, 0.035, 12, 48]} />
        <meshStandardMaterial color={colors.paper} />
      </mesh>
    </mesh>
  )
}

function Die() {
  const ref = useRef<Group>(null)
  useFrame((state) => {
    if (!ref.current) return
    ref.current.rotation.x = state.clock.elapsedTime * 0.3
    ref.current.rotation.y = state.clock.elapsedTime * 0.42
  })
  return (
    <Float speed={1.4} rotationIntensity={0.25} floatIntensity={0.35}>
      <group ref={ref} position={[-3.3, 1.2, 1.5]}>
        <RoundedBox args={[0.9, 0.9, 0.9]} radius={0.17} smoothness={4}>
          <meshStandardMaterial color={colors.paper} roughness={0.35} />
        </RoundedBox>
        {[[0, 0.46, 0], [0.22, 0.46, 0.22], [-0.22, 0.46, -0.22]].map((p, i) => (
          <mesh key={i} position={p as [number, number, number]} rotation={[Math.PI / 2, 0, 0]}>
            <cylinderGeometry args={[0.065, 0.065, 0.025, 24]} />
            <meshStandardMaterial color={colors.red} />
          </mesh>
        ))}
      </group>
    </Float>
  )
}

function Pawn() {
  return (
    <Float speed={1.1} floatIntensity={0.18} rotationIntensity={0.08}>
      <group position={[2.65, 0.78, 1.65]}>
        <mesh position={[0, 0.52, 0]}>
          <sphereGeometry args={[0.3, 32, 32]} />
          <meshStandardMaterial color={colors.blue} roughness={0.38} />
        </mesh>
        <mesh position={[0, 0.03, 0]}>
          <coneGeometry args={[0.52, 0.82, 32]} />
          <meshStandardMaterial color={colors.blue} roughness={0.4} />
        </mesh>
        <mesh position={[0, -0.39, 0]}>
          <cylinderGeometry args={[0.58, 0.58, 0.12, 32]} />
          <meshStandardMaterial color={colors.ink} />
        </mesh>
      </group>
    </Float>
  )
}

function Board() {
  const ref = useRef<Group>(null)
  useFrame((state) => {
    if (!ref.current) return
    const targetX = state.pointer.y * 0.12 - 0.52
    const targetY = state.pointer.x * 0.18 - 0.48
    ref.current.rotation.x += (targetX - ref.current.rotation.x) * 0.035
    ref.current.rotation.y += (targetY - ref.current.rotation.y) * 0.035
  })

  const tiles = [
    [-2.55, 0.23, -2.55, colors.blue], [-1.25, 0.23, -2.55, colors.paper], [0, 0.23, -2.55, colors.green], [1.25, 0.23, -2.55, colors.paper], [2.55, 0.23, -2.55, colors.red],
    [2.55, 0.23, -1.25, colors.paper], [2.55, 0.23, 0, colors.orange], [2.55, 0.23, 1.25, colors.paper], [2.55, 0.23, 2.55, colors.yellow],
    [1.25, 0.23, 2.55, colors.paper], [0, 0.23, 2.55, colors.blue], [-1.25, 0.23, 2.55, colors.paper], [-2.55, 0.23, 2.55, colors.green],
    [-2.55, 0.23, 1.25, colors.paper], [-2.55, 0.23, 0, colors.red], [-2.55, 0.23, -1.25, colors.paper]
  ] as const

  return (
    <group ref={ref} rotation={[-0.52, -0.48, 0]}>
      <RoundedBox args={[6.7, 0.38, 6.7]} radius={0.22} smoothness={4} position={[0, 0, 0]}>
        <meshStandardMaterial color={colors.ink} roughness={0.6} />
      </RoundedBox>
      <RoundedBox args={[6.35, 0.14, 6.35]} radius={0.16} smoothness={4} position={[0, 0.24, 0]}>
        <meshStandardMaterial color={colors.yellow} roughness={0.72} />
      </RoundedBox>
      {tiles.map(([x, y, z, color], i) => (
        <RoundedBox key={i} args={[1.08, 0.12, 1.08]} radius={0.08} smoothness={3} position={[x, y + 0.1, z]}>
          <meshStandardMaterial color={color} roughness={0.65} />
        </RoundedBox>
      ))}
      <mesh position={[0, 0.35, 0]} rotation={[-Math.PI / 2, 0, Math.PI / 4]}>
        <ringGeometry args={[1.25, 1.32, 64]} />
        <meshStandardMaterial color={colors.ink} />
      </mesh>
      <House position={[-1.55, 0.36, -0.5]} color={colors.blue} />
      <House position={[1.15, 0.36, 0.72]} color={colors.green} scale={0.78} />
      <Coin position={[3.45, 1.2, -1.6]} speed={1.15} />
      <Coin position={[-3.45, 0.65, -0.8]} color={colors.green} speed={0.8} />
      <Die />
      <Pawn />
    </group>
  )
}

export default function BoardScene() {
  return (
    <Canvas dpr={[1, 1.7]} camera={{ position: [0, 5.3, 9.2], fov: 38 }} gl={{ antialias: true }}>
      <color attach="background" args={['#f2eee2']} />
      <ambientLight intensity={1.7} />
      <directionalLight position={[5, 8, 4]} intensity={3.2} castShadow />
      <Board />
      <ContactShadows position={[0, -1.45, 0]} opacity={0.22} scale={13} blur={2.5} far={5} />
      <Environment preset="city" />
    </Canvas>
  )
}
