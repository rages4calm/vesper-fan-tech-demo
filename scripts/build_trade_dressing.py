"""Original Blender set dressing, using the project's licensed Poly Haven maps.
Run Blender --background --python scripts/build_trade_dressing.py.
Axes in helper arguments are Godot X,Y(up),Z; export is glTF Y-up.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/art'; OUT.mkdir(parents=True,exist_ok=True)
MAPS=ROOT/'godot/assets/materials'
random.seed(271)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def material(name,color,texture=None,roughness=.85,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=roughness
    bs.inputs['Metallic'].default_value=metal
    if texture:
        for suffix,target in [('diff','Base Color'),('rough','Roughness'),('nor_gl','Normal')]:
            image=bpy.data.images.load(str(MAPS/f'{texture}_{suffix}.jpg'),check_existing=True)
            tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
            if suffix!='diff':image.colorspace_settings.name='Non-Color'
            if suffix=='nor_gl':
                normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.4
                m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],bs.inputs[target])
            else:m.node_tree.links.new(tex.outputs['Color'],bs.inputs[target])
    return m

wood=material('Dressing · worn oak',(.32,.23,.14),'brown_planks_03')
iron=material('Dressing · forged iron',(.065,.06,.052),roughness=.65,metal=.55)
rope=material('Dressing · hemp',(.28,.22,.13))
fishmat=material('Dressing · silver catch',(.28,.35,.32),roughness=.52,metal=.15)
cloth=material('Dressing · undyed linen',(.40,.34,.23))
gold=material('Dressing · ochre paint',(.58,.39,.13))
clay=material('Dressing · clayware',(.24,.10,.055))
glass=material('Dressing · green bottles',(.065,.12,.073),roughness=.38)

def loc(p):return (p[0],-p[2],p[1])
def finish(o,name,mat):
    o.name=name;o.data.materials.append(mat)
    if o.type=='MESH':
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        mod=o.modifiers.new('Soft worn edges','BEVEL');mod.width=.014;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.select_set(False)
    return o
def box(p,size,mat=wood,name='Plank',yaw=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc(p))
    o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);o.rotation_euler.z=-yaw
    return finish(o,name,mat)
def beam(a,b,r=.03,mat=rope,name='Rope'):
    av,bv=Vector(loc(a)),Vector(loc(b));delta=bv-av
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=delta.length,location=(av+bv)/2)
    o=bpy.context.object;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return finish(o,name,mat)
def ellipsoid(p,size,mat,name='Object'):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=loc(p))
    o=bpy.context.object;o.scale=(size[0],size[2],size[1])
    return finish(o,name,mat)
def ring(p,r=.42,tube=.026,mat=iron,vertical=False):
    bpy.ops.mesh.primitive_torus_add(major_segments=28,minor_segments=6,major_radius=r,minor_radius=tube,location=loc(p))
    o=bpy.context.object
    if vertical:o.rotation_euler.x=math.pi/2
    return finish(o,'Hoop',mat)
def barrel(x,y,z,r=.42,h=1.1):
    # Separate bevelled staves, gently bulging center, two iron bands and wooden lid.
    for i in range(16):
        a=math.tau*i/16
        stave=box((x+math.cos(a)*r,y+h*.5,z+math.sin(a)*r),(.16,h,.075),name='Oak stave',yaw=math.pi/2-a)
    for yy in [.16,h-.16]:ring((x,y+yy,z),r+.028)
    for i in range(-2,3):
        xx=i*.15;length=2*math.sqrt(max(.01,r*r-xx*xx))
        box((x+xx,y+h-.04,z),(.145,.07,length),name='Barrel lid')
    beam((x,y+h+.01,z),(x,y+h+.035,z),.055,iron,'Bung')
def coil(x,y,z):
    for i in range(4):ring((x,y+.04,z),.17+i*.055,.018,rope)
def fish(p,scale=.55):
    x,y,z=p
    ellipsoid(p,(.095*scale,.35*scale,.055*scale),fishmat,'Dried fish')
    box((x,y-.32*scale,z),(.17*scale,.10*scale,.035*scale),fishmat,'Tail')
def export(name):
    bpy.ops.object.select_all(action='SELECT')
    for obj in bpy.context.selected_objects:
        if obj.type=='MESH':
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    bpy.ops.object.delete(use_global=False)

# Hanging net, float line and five fish; all supported by heavy timber uprights.
for x in [-1.7,1.7]:
    box((x,1.2,0),(.14,2.4,.14));box((x,.10,0),(.55,.2,.7))
beam((-1.78,2.3,0),(1.78,2.3,0),.075,wood,'Cross rail')
for j in range(10):
    x=-1.6+j*.35
    for k in range(6):
        ya=.7+k*.23;yb=ya+.23
        beam((x,ya,.07+math.sin(j)*.04),(x+.17,yb,.07),.009)
        beam((x+.17,yb,.07),(x+.35,ya,.07),.009)
for i in range(5):
    x=-1.3+i*.62
    beam((x,2.25,-.16),(x,1.82,-.16),.018)
    fish((x,1.64,-.16),.85)
    ellipsoid((x,2.28,.02),(.08,.065,.07),wood,'Net float')
barrel(1.10,0,.5,r=.32,h=.65);coil(-1.10,0,.38)
export('fishing_rack')

# Timber trestles, irregular planks, a hand saw and mallet.
for x in [-1.25,1.25]:
    for z in [-.40,.40]:beam((x,0,z),(x,1.02,z*.3),.075,wood,'Trestle leg')
    box((x,1.04,0),(.18,.18,1.15))
for row in range(3):
    for i in range(4):box((random.uniform(-.12,.12),1.20+row*.11,-.37+i*.25),(3.8-random.random()*.3,.095,.21),name='Seasoned plank')
box((.3,1.53,0),(.9,.055,.13),iron,'Saw blade',yaw=.2)
ring((.84,1.55,.12),.13,.035,wood)
beam((-.8,1.55,-.3),(-.4,1.55,.25),.033,wood,'Mallet handle')
box((-.8,1.61,-.3),(.25,.18,.18),iron,'Mallet head')
export('timber_work')

# Coiled mooring lines and stacked oak casks.
barrel(-.65,0,0);barrel(.35,0,.1);barrel(-.14,1.08,.05,r=.35,h=.9)
coil(1.05,0,.05);coil(.9,0,.7)
export('quay_casks')

# Shopkeeper's wall shelf: crockery, jars, sacks and dried herbs.
for y in [.7,1.7,2.7]:
    box((0,y,0),(3.6,.13,.45))
    for x in [-1.3,1.3]:beam((x,y-.45,-.17),(x,y,.2),.045,iron,'Shelf bracket')
for i in range(10):
    x=-1.5+i*.32
    ellipsoid((x,.94,0),(.105,.19,.105),clay,'Earthenware')
    beam((x,1.08,0),(x,1.15,0),.062,clay,'Jar neck')
for i in range(8):
    x=-1.35+i*.38
    ellipsoid((x,1.99,0),(.12,.23,.11),glass,'Bottle')
    beam((x,2.14,0),(x,2.35,0),.042,glass,'Bottle neck')
for x in [-1.1,-.3,.5,1.2]:ellipsoid((x,2.98,0),(.24,.24,.15),cloth,'Linen sack')
export('trade_shelf')

# Backbar: patterned vertical boards, shelf, barrels and tavern name plaque.
for x in range(-12,13):box((x*.30,1.7,0),(.285,3.4,.08))
for y in [.14,1.65,3.28]:box((0,y,.06),(7.7,.12,.12))
for x in [-2.5,0,2.5]:barrel(x,.2,.5,r=.58,h=1.4)
box((0,2.1,.35),(7.6,.12,.60))
for i in range(11):
    x=-3.3+i*.64
    ellipsoid((x,2.32,.4),(.12,.17,.12),clay,'Tankard')
    ring((x+.12,2.33,.40),.075,.025,clay,vertical=True)
export('tavern_backbar')

# Physical trade pictograms, replacing the indistinct generic circular marks.
for kind in ['fish','hammer','mug','bread','anchor','bottle']:
    box((0,0,0),(1.42,.90,.12),wood,'Sign board')
    for yy in [-.34,.34]:box((0,yy,.075),(1.30,.055,.045),iron,'Forged strap')
    if kind=='fish':
        ellipsoid((0,0,.11),(.37,.13,.035),gold,'Fish emblem');box((-.38,0,.11),(.18,.24,.045),gold,'Tail')
    elif kind=='hammer':
        beam((-.2,-.24,.12),(.14,.20,.12),.06,gold);box((.13,.2,.12),(.5,.17,.06),gold)
    elif kind=='mug':
        box((-.08,0,.11),(.36,.43,.05),gold);ring((.18,.03,.11),.14,.036,gold,vertical=True)
    elif kind=='bread':
        ellipsoid((0,0,.11),(.43,.19,.045),gold,'Loaf emblem')
        for x in [-.22,0,.22]:beam((x-.035,-.08,.165),(x+.035,.09,.165),.018,wood,'Bread scoring')
    elif kind=='anchor':
        beam((0,-.25,.12),(0,.21,.12),.036,gold);ring((0,.24,.12),.08,.027,gold,True)
        beam((-.3,-.08,.12),(0,-.27,.12),.038,gold);beam((.3,-.08,.12),(0,-.27,.12),.038,gold)
        beam((-.22,.04,.12),(.22,.04,.12),.025,gold)
    else:
        ellipsoid((0,-.05,.11),(.20,.22,.045),gold);box((0,.19,.11),(.13,.22,.05),gold)
    export('sign_'+kind)

entries=[
    dict(id='fishers_net_rack',asset='fishing_rack',position=[108.0,2,-40.9],yaw=0,obstacles=[[0,1.1,.15,3.7,2.3,.9]]),
    dict(id='shipwright_timber',asset='timber_work',position=[98.0,2,-3.8],yaw=0,obstacles=[[0,.8,0,4.0,1.6,1.1]]),
    dict(id='carpenters_timber',asset='timber_work',position=[22.8,2,-23.6],yaw=math.pi/2,obstacles=[[0,.8,0,4,1.6,1.1]]),
    dict(id='shipwright_casks',asset='quay_casks',position=[102.0,3.16,-3.75],yaw=0,obstacles=[]),
    dict(id='tavern_backbar',asset='tavern_backbar',position=[4.45,2,70.1],yaw=math.pi/2,obstacles=[]),
    dict(id='tavern_crockery',asset='trade_shelf',position=[14.4,2.2,64.5],yaw=0,obstacles=[]),
    dict(id='inn_crockery',asset='trade_shelf',position=[-92,2.2,116.9],yaw=0,obstacles=[]),
]
plan=json.loads((ROOT/'godot/assets/town_plan.json').read_text())
for ident,kind in [('fisher','fish'),('carpenter','hammer'),('tavern','mug'),('inn','mug'),('oven','bread'),('boat','anchor'),('healer','bottle'),('reagents','bottle'),('brew','bottle')]:
    b=next(b for b in plan['buildings'] if b['id']==ident)
    if ident in ['boat','fisher']:
        door=b['doors'][0];yaw=door['yaw'];nx,nz=math.sin(yaw),math.cos(yaw);tx,tz=math.cos(yaw),-math.sin(yaw)
        p=[door['pos'][0]+tx*1.9+nx*1.27,4.9,door['pos'][2]+tz*1.9+nz*1.27]
    else:yaw=0;p=[b['pos'][0]+2.2,4.4,b['pos'][1]+b['depth']/2+1.62]
    entries.append(dict(id=ident+'_trade_sign',asset='sign_'+kind,position=p,yaw=yaw,obstacles=[]))
(OUT/'trade_dressing.json').write_text(json.dumps(entries,indent=2))
print('TRADE_DRESSING_COMPLETE',len(entries),'placements')
