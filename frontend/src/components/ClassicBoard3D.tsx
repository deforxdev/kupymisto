import { Canvas, useFrame } from '@react-three/fiber'
import { ContactShadows, Environment, Float, RoundedBox, Text } from '@react-three/drei'
import { useMemo, useRef } from 'react'
import type { Group, Mesh } from 'three'
import type { BoardSize, Player } from '../api'

export type BoardCell = { name: string; kind: 'corner'|'city'|'chance'|'tax'|'station'; price?: number; color: string }

const cityNames = ['Київ','Львів','Одеса','Харків','Дніпро','Чернівці','Ужгород','Луцьк','Рівне','Житомир','Вінниця','Полтава','Черкаси','Суми','Чернігів','Тернопіль','Івано-Франківськ','Миколаїв','Херсон','Запоріжжя','Кропивницький','Біла Церква','Кременчук','Кам’янець']
const bands = ['#6e4a2c','#6e4a2c','#69b8d8','#69b8d8','#d55c8b','#d55c8b','#e87942','#e87942','#d94d45','#d94d45','#efc63e','#efc63e','#55a96a','#55a96a','#4574cf','#4574cf']

export function makeCells(size: BoardSize): BoardCell[] {
  const side = size === 'large' ? 15 : 11
  const total = side * 4 - 4
  let city = 0
  return Array.from({ length: total }, (_, index) => {
    if (index % (side - 1) === 0) {
      const corners = ['СТАРТ','ВІЛЬНА ЗУПИНКА','МІСЬКА РАДА','ПАРКІНГ']
      return { name: corners[index / (side - 1)], kind: 'corner', color: index === 0 ? '#efc63e' : '#e9e5d7' }
    }
    if (index % 7 === 0) return { name: 'ШАНС', kind: 'chance', color: '#e9e5d7' }
    if (index % 9 === 0) return { name: 'ЗБІР', kind: 'tax', color: '#e9e5d7' }
    if (index % 5 === 0) return { name: 'ВОКЗАЛ', kind: 'station', price: 200, color: '#e9e5d7' }
    const name = cityNames[city % cityNames.length]
    const color = bands[Math.floor(city / 2) % bands.length]
    city++
    return { name, kind: 'city', price: 100 + (city % 9) * 30, color }
  })
}

function boardPosition(index: number, side: number): [number, number, number] {
  const edge = side - 1
  const half = edge / 2
  if (index <= edge) return [half - index, 0, half]
  if (index <= edge * 2) return [-half, 0, half - (index - edge)]
  if (index <= edge * 3) return [-half + (index - edge * 2), 0, -half]
  return [half, 0, -half + (index - edge * 3)]
}

function Token({ index, side, color, offset }: { index:number; side:number; color:string; offset:number }) {
  const ref = useRef<Group>(null)
  const [x,,z] = boardPosition(index, side)
  useFrame(() => {
    if (!ref.current) return
    ref.current.position.x += (x + offset - ref.current.position.x) * .08
    ref.current.position.z += (z + offset - ref.current.position.z) * .08
  })
  return <group ref={ref} position={[x + offset,.45,z + offset]}>
    <mesh position={[0,.28,0]} castShadow><sphereGeometry args={[.16,24,24]}/><meshStandardMaterial color={color}/></mesh>
    <mesh castShadow><coneGeometry args={[.28,.55,24]}/><meshStandardMaterial color={color}/></mesh>
    <mesh position={[0,-.29,0]} castShadow><cylinderGeometry args={[.31,.31,.09,24]}/><meshStandardMaterial color="#20202a"/></mesh>
  </group>
}

function Die({ position, value, rolling }: { position:[number,number,number]; value:number; rolling:boolean }) {
  const ref = useRef<Mesh>(null)
  useFrame((_,delta) => { if (rolling && ref.current) { ref.current.rotation.x += delta*8; ref.current.rotation.z += delta*6 } })
  return <Float speed={1.2} floatIntensity={.12} rotationIntensity={.08}>
    <RoundedBox ref={ref} args={[.72,.72,.72]} radius={.12} smoothness={4} position={position} castShadow>
      <meshStandardMaterial color="#f3efe3" roughness={.38}/>
      <Text position={[0,.371,0]} rotation={[-Math.PI/2,0,0]} fontSize={.28} color="#20202a" anchorX="center" anchorY="middle">{String(value)}</Text>
    </RoundedBox>
  </Float>
}

function BoardModel({ size, positions, players, dice, rolling }: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const group = useRef<Group>(null)
  const cells = useMemo(() => makeCells(size), [size])
  const side = size === 'large' ? 15 : 11
  const edge = side - 1
  const boardWidth = edge + 1.7
  const playerColors = ['#3167dc','#de5549','#54b87a','#efc63e','#955fc7','#e98a44']

  useFrame((state) => {
    if (!group.current) return
    group.current.rotation.y += (state.pointer.x * .09 - group.current.rotation.y) * .025
    group.current.rotation.x += ((-.05 + state.pointer.y * .035) - group.current.rotation.x) * .025
  })

  return <group ref={group}>
    <RoundedBox args={[boardWidth,.34,boardWidth]} radius={.18} smoothness={4} receiveShadow>
      <meshStandardMaterial color="#20202a" roughness={.68}/>
    </RoundedBox>
    <RoundedBox args={[boardWidth-.3,.18,boardWidth-.3]} radius={.12} smoothness={4} position={[0,.25,0]} receiveShadow>
      <meshStandardMaterial color="#dce7da" roughness={.78}/>
    </RoundedBox>
    {cells.map((cell,index) => {
      const [x,,z] = boardPosition(index,side)
      const corner = cell.kind === 'corner'
      const rotation = index <= edge ? 0 : index <= edge*2 ? Math.PI/2 : index <= edge*3 ? Math.PI : -Math.PI/2
      return <group key={index} position={[x,.38,z]} rotation={[0,rotation,0]}>
        <RoundedBox args={[corner?1.05:.78,.10,1.05]} radius={.035} smoothness={2} receiveShadow>
          <meshStandardMaterial color={corner?cell.color:'#f3efe3'} roughness={.7}/>
        </RoundedBox>
        {!corner && <mesh position={[0,.075,-.38]}><boxGeometry args={[.76,.035,.26]}/><meshStandardMaterial color={cell.color}/></mesh>}
        <Text position={[0,.095,.05]} rotation={[-Math.PI/2,0,0]} fontSize={corner?.12:.09} maxWidth={.68} color="#20202a" textAlign="center" anchorX="center" anchorY="middle">{cell.name}</Text>
        {cell.price && <Text position={[0,.096,.28]} rotation={[-Math.PI/2,0,0]} fontSize={.07} color="#20202a" anchorX="center" anchorY="middle">{cell.price} ₴</Text>}
      </group>
    })}
    <group position={[0,.38,0]} rotation={[0,-Math.PI/4,0]}>
      <Text fontSize={size==='large'?.76:.92} color="#20202a" anchorX="center" anchorY="middle">КУПИМІСТО</Text>
      <Text position={[0,-.58,0]} fontSize={.18} color="#496b58" anchorX="center" anchorY="middle">УКРАЇНСЬКА ОНЛАЙН-ГРА</Text>
    </group>
    {players.map((player,index) => <Token key={player.id} index={positions[index]||0} side={side} color={playerColors[index%playerColors.length]} offset={(index%3-.8)*.16}/>)}
    <Die position={[-.5,.78,.45]} value={dice[0]} rolling={rolling}/><Die position={[.5,.78,.45]} value={dice[1]} rolling={rolling}/>
  </group>
}

export default function ClassicBoard3D(props: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const camera = props.size === 'large' ? [0,12.5,13.8] as [number,number,number] : [0,10.8,12.5] as [number,number,number]
  return <Canvas dpr={[1,1.6]} shadows camera={{ position:camera, fov:38 }} gl={{ antialias:true }}>
    <color attach="background" args={['#dce7da']}/><ambientLight intensity={1.6}/><directionalLight position={[7,12,5]} intensity={3.1} castShadow shadow-mapSize={[1024,1024]}/>
    <BoardModel {...props}/><ContactShadows position={[0,-.2,0]} opacity={.22} scale={19} blur={2.5} far={8}/><Environment preset="city"/>
  </Canvas>
}
