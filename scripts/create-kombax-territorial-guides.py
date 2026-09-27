from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Image
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import mm
from pathlib import Path
import json,re,unicodedata

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'/'guides'/'territories'
SRC=ROOT/'docs'/'10_GUIDES_TERRITORIES'
OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(parents=True,exist_ok=True)
REVIEW='21/09/2026'
HERO=ROOT/'artifacts'/'assets'/'kombax-guides-hero.webp'

pdfmetrics.registerFont(TTFont('DejaVu','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Bold','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))

# Only official/public-administration sources. No commercial legal summaries.
S={
'andalucia_reg':('Registro Andaluz de Entidades Deportivas (RAED)','Junta de Andalucía','https://www.juntadeandalucia.es/organismos/culturapatrimoniohistoricoydeporte/areas/deporte/entidades-deportivas/registro-entidades-deportivas.html'),
'andalucia_club':('Clubes deportivos: reconocimiento, inscripción y cancelación','Junta de Andalucía','https://www.juntadeandalucia.es/servicios/sede/tramites/procedimientos/detalle/1075'),
'andalucia_minor':('Protocolo marco de protección de menores frente a la violencia en el deporte','Junta de Andalucía','https://www.juntadeandalucia.es/servicios/sede/tramites/procedimientos/detalle/25660.html'),
'aragon_law':('Ley 16/2018, de actividad física y deporte de Aragón','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2019-993'),
'aragon_reg':('Registro de entidades deportivas de Aragón','Gobierno de Aragón','https://www.aragon.es/tramitador/-/tramite/gestion-registro-general-entidades-deportivas-aragon'),
'asturias_law':('Ley 5/2022, de Actividad Física y Deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2022-11961'),
'asturias_reg':('Registro de clubes y entidades deportivas','Deporte Asturiano - Principado de Asturias','https://deporte.asturias.es/registro-de-clubes'),
'asturias_protocol':('Legislación y protocolos de protección en el deporte','Deporte Asturiano - Principado de Asturias','https://deporte.asturias.es/legislacion'),
'balears_law':('Ley 2/2023, de actividad física y deporte de las Illes Balears','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2023-13669'),
'balears_general':("Inscripción de club deportivo de régimen general",'Govern de les Illes Balears','https://www.caib.es/sites/entitatsesportives/ca/inscripcio_dun_club_esportiu-60188/'),
'balears_special':("Inscripción de club deportivo de régimen especial",'Govern de les Illes Balears','https://www.caib.es/sites/entitatsesportives/ca/inscripcia_dun_club_esportiu_de_ragim_especial/'),
'balears_proc':('Constitución de club deportivo de régimen general','Seu electrònica CAIB','https://www.caib.es/seucaib/ca/200/persones%20/tramites/tramite/2157063'),
'canarias_law':('Ley 1/2019, de la Actividad Física y el Deporte de Canarias','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2019-2713'),
'canarias_reg':('Procedimiento del Registro de Entidades Deportivas de Canarias','Gobierno de Canarias','https://www.gobiernodecanarias.org/deportes/servicios/registro-entidades-deportivas/procedimiento/index.html'),
'cantabria_law':('Ley 2/2000, de 3 de julio, del Deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2000-14000'),
'cantabria_clubs':('Regulación de clubes deportivos en Cantabria','Boletín Oficial de Cantabria','https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=8909'),
'clm_law':('Ley 5/2015, de Actividad Física y Deporte de Castilla-La Mancha','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2015-6879'),
'clm_clubs':('Clubes deportivos de Castilla-La Mancha','Portal de Deportes de Castilla-La Mancha','https://deportes.castillalamancha.es/federaciones-y-clubes/clubes-deportivos'),
'clm_reg':('Trámites de federaciones y clubes / Registro de Entidades Deportivas','Portal de Deportes de Castilla-La Mancha','https://deportes.castillalamancha.es/federaciones-y-clubes/tramites-de-federaciones-y-clubes'),
'cyl_law':('Ley 3/2019, de la Actividad Físico-Deportiva de Castilla y León','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2019-4455'),
'cyl_reg':('Registro de Entidades Deportivas de Castilla y León','Junta de Castilla y León','https://www.tramitacastillayleon.jcyl.es/web/jcyl/AdministracionElectronica/es/Plantilla100Detalle/1251181050732/Tramite/1220528882270/Tramite'),
'cat_law':('Texto único de la Ley del deporte de Cataluña','BOE','https://www.boe.es/buscar/act.php?id=DOGC-f-2000-90007'),
'cat_reg':("Registre d'Entitats Esportives",'Generalitat de Catalunya','https://esport.gencat.cat/ca/arees_dactuacio/entitats-esportives/registre-dentitats-esportives-ree'),
'cat_club':('Inscripción en el Registro de Entidades Deportivas','Tràmits Gencat','https://tramits.gencat.cat/es/tramits/tramits-temes/21441-Inscripcio-al-Registre-dEntitats-Esportives?moda=1'),
'cat_events':('Espectáculos y actividades recreativas de carácter extraordinario','Generalitat de Catalunya - Interior','https://interior.gencat.cat/es/arees_dactuacio/espectacles/espectacles_i_activitats_caracter_extraordinari/'),
'cat_minor':('Protocolo marco de protección de infancia y adolescencia frente a violencias en deporte','Generalitat de Catalunya - Esport','https://esport.gencat.cat/web/.content/home/secretaria_general_de_lesport/Consell_Catala_Esport/normativa/acord_gov_23_protocol_proteccio_violencia.pdf'),
'val_law':('Ley 2/2011, del deporte y la actividad física de la Comunitat Valenciana','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2011-6874'),
'val_reg':('Inscripción en el Registro de Entidades Deportivas de la Comunitat Valenciana','Generalitat Valenciana','https://sede.gva.es/es/detall-tramit?id_proc=193'),
'ext_law':('Ley 2/1995, del Deporte de Extremadura','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1995-12743'),
'ext_reg':('Registro General de Entidades Deportivas de Extremadura','Junta de Extremadura','https://www.juntaex.es/w/1887?inheritRedirect=true'),
'gal_law':('Ley 3/2012, del deporte de Galicia - texto consolidado','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2012-5596'),
'gal_reg':('Rexistro de Entidades Deportivas de Galicia','Xunta de Galicia - Deporte Galego','https://deporte.xunta.gal/gl/node/6641'),
'gal_proc':('PR946A - Inscripción no rexistro de entidades deportivas','Sede Xunta de Galicia','https://sede.xunta.gal/detalle-procedemento?c=empresas-e-profesionais&codtram=PR946A&langId=es_ES'),
'mad_law':('Ley 15/1994, del Deporte de la Comunidad de Madrid','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1995-8733'),
'mad_reg':('Registro de Entidades Deportivas','Comunidad de Madrid','https://sede.comunidad.madrid/inscripciones-registro/registro-entidades-deportivas'),
'mur_law':('Ley 8/2015, de Actividad Física y Deporte de la Región de Murcia','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2015-4749'),
'mur_reg':('Inscripción de constitución y revocación de clubes deportivos','Sede CARM','https://sede.carm.es/web/pagina?IDCONTENIDO=2044&IDTIPO=240&RASTRO=c%24m40293'),
'nav_law':('Ley Foral 15/2001, del Deporte de Navarra','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2001-15675'),
'nav_reg':('Inscripción de entidades deportivas en el Registro del Deporte de Navarra','Gobierno de Navarra','https://www.navarra.es/es/tramites/on/-/line/inscripcion-de-entidades-deportivas-en-el-registro-del-deporte-de-navarra'),
'nav_prof':('Inscripción de profesionales en el Registro del Deporte de Navarra','Gobierno de Navarra','https://www.navarra.es/es/tramites/on/-/line/inscripcion-de-profesionales-en-el-registro-del-deporte'),
'pv_law':('Ley 2/2023, de actividad física y deporte del País Vasco','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2023-10639'),
'pv_reg':('Registro de Entidades Deportivas','Gobierno Vasco','https://www.euskadi.eus/registro/registro-entidades-deportivas/web01-tramite/es/'),
'rio_law':('Ley 1/2015, del ejercicio físico y deporte de La Rioja','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2015-4028'),
'rio_reg':('Registro General de Entidades Deportivas: constitución e inscripción de un Club Deportivo','Gobierno de La Rioja','https://web.larioja.org/oficina-electronica/tramite?n=21709'),
'ceuta_reg':('Reglamento del Registro General de Asociaciones Deportivas','Ciudad Autónoma de Ceuta','https://www.ceuta.es/ceuta/biblioteca/46-paginas/paginas/normativa/91-reglamento-del-registro-general-de-asociaciones-deportivas-de-25-de-abril-de-2000'),
'ceuta_club':('Reglamento de Asociaciones Deportivas','Ciudad Autónoma de Ceuta','https://www.ceuta.es/ceuta/noticias-deportes/46-paginas/paginas/normativa/93-reglamento-por-el-que-se-regulan-las-asociaciones-deportivas-de-25-de-abril-de-2000'),
'mel_reg':('Solicitud de registro de entidades, clubes y asociaciones deportivas','Sede de la Ciudad Autónoma de Melilla','https://sede.melilla.es/sta/Relec/CatalogDetail?dboidRequest=6269001013544443599500'),
'mel_bome':('Reglamentos deportivos publicados en BOME Extraordinario 20 de 25/06/1999','Ciudad Autónoma de Melilla - BOME','https://www.melilla.es/melillaPortal/contenedor.jsp?codAdirecto=15&codResi=1&dboidboletin=289809&language=es&seccion=ficha_bome.jsp'),
}

COMMON=[
'La Ley 39/2022 del Deporte constituye el marco estatal, pero no sustituye la normativa autonómica ni los reglamentos federativos o municipales aplicables al caso concreto.',
'Para una velada, interclub o actividad con público, KOMBAX no presume una autorización única: debe verificarse la clasificación real de la actividad, el recinto, el municipio, la normativa autonómica de espectáculos/actividades, la federación o entidad deportiva competente y las condiciones de seguros y asistencia.',
'Con menores se aplican, como mínimo, las obligaciones estatales de protección frente a la violencia; cuando el territorio publique protocolos o trámites propios, se identifican expresamente.',
]

T=[]
def add(code,name,aliases,summary,diffs,sources,consult,notes=None):
    T.append(dict(code=code,name=name,aliases=aliases,summary=summary,differentials=diffs,sources=sources,consult=consult,notes=notes or []))

add('AN','Andalucía',['andalucia','andalucía'],
'Andalucía cuenta con Registro Andaluz de Entidades Deportivas y regulación propia de clubes. Además dispone de un protocolo marco autonómico específico para entidades que realizan actividad deportiva con menores.',[
('Entidades y registro','verified','El RAED inscribe las entidades deportivas con domicilio en Andalucía. Los clubes son asociaciones sin ánimo de lucro y la normativa andaluza distingue, entre otros extremos, clubes orientados a deporte de competición y de ocio.'),
('Constitución de club','verified','El procedimiento oficial exige solicitud, acta fundacional y acuerdo de aprobación de estatutos conforme a la Ley andaluza y al Decreto 41/2022. La guía no fija un número de fundadores porque el trámite debe leerse con la versión vigente del decreto y los modelos oficiales.'),
('Menores','verified','El Protocolo Marco aprobado por Orden de 18/11/2024 se aplica a entidades que realizan actividad deportiva con menores; la Junta publica adhesión, designación de delegado/a del menor, análisis de riesgos, código de conducta y canal de denuncia.'),
('Eventos e interclubs','case','Antes de anunciar una velada como competición, exhibición o interclub hay que verificar federación/modalidad, recinto, ayuntamiento y régimen de espectáculos o actividad. No se traslada al usuario una regla única no verificada.')],
['andalucia_reg','andalucia_club','andalucia_minor'],
['Evento con menores, público o deportistas extranjeros.','Dudas sobre modalidad/federación o carácter oficial.','Necesidad de revisar expediente de club, protocolo de menores o documentación del recinto.'])

add('AR','Aragón',['aragon','aragón'],
'Aragón regula la actividad física y el deporte mediante la Ley 16/2018 y dispone de Registro General de Entidades Deportivas.',[
('Constitución de club','verified','La Ley 16/2018 establece que la constitución de un club deportivo requiere el acuerdo de tres o más personas físicas o jurídicas legalmente constituidas, con acta fundacional y estatutos.'),
('Reconocimiento deportivo','verified','El reconocimiento del club a efectos deportivos se acredita mediante la inscripción en el Registro de Entidades Deportivas de Aragón.'),
('Tramitación registral','verified','El portal autonómico permite inscripción, comunicación de modificaciones y solicitud de certificados/copias.'),
('Eventos e interclubs','case','La ley deportiva no convierte por sí sola cualquier velada en actividad autorizada: deben cruzarse recinto, municipio, modalidad/federación, seguros y, si procede, normativa de espectáculos.')],
['aragon_law','aragon_reg'],
['Club con varias modalidades o actividad fuera de Aragón.','Evento con público, menores o ticketing.','Duda sobre si la actividad es competición oficial, exhibición o entrenamiento.'])

add('AS','Principado de Asturias',['asturias','principado de asturias'],
'Asturias diferencia equipos deportivos y clubes básicos y publica requisitos registrales específicos y protocolos de protección.',[
('Tipos de entidad','verified','El portal oficial distingue equipos deportivos y clubes deportivos básicos, además de otras formas. Los equipos son una fórmula diferenciada de los clubes básicos.'),
('Club básico','verified','La información oficial del Registro indica acta fundacional suscrita por un mínimo de cinco personas mayores de edad y escritura pública para el club básico.'),
('Registro','verified','El portal informa de un plazo máximo administrativo de tres meses y silencio positivo para el Registro de Entidades Deportivas.'),
('Protección','verified','Deporte Asturiano publica protocolos específicos frente a violencia contra menores y frente a violencia sexual contra las mujeres en el deporte.'),
('Eventos e interclubs','case','La clasificación del evento, seguros, recinto y requisitos federativos deben revisarse para el supuesto concreto.')],
['asturias_law','asturias_reg','asturias_protocol'],
['Elegir entre equipo deportivo y club básico.','Evento con menores o necesidad de protocolo.','Velada con público o uso de recinto con condiciones especiales.'])

add('IB','Illes Balears',['illes balears','islas baleares','baleares','balears'],
'Illes Balears tiene una ley deportiva de 2023 y mantiene vías diferenciadas para clubes de régimen general y especial.',[
('Régimen general','verified','El procedimiento oficial de régimen general exige acta suscrita por un mínimo de cinco personas físicas o jurídicas y estatutos; la solicitud se presenta dentro de los tres meses desde la autorización de la denominación.'),
('Régimen especial','verified','La vía de régimen especial/simplificado publicada por el Registro exige un mínimo de tres personas físicas y estatutos conforme a la normativa aplicable.'),
('Registro','verified','La sede electrónica publica el procedimiento y referencia el Decreto 33/2014 del Registro de Entidades Deportivas.'),
('Eventos e interclubs','case','No se presume que el régimen de club resuelva permisos de una velada: deben verificarse isla/municipio, recinto, espectáculo/actividad, seguros y federación/modalidad.')],
['balears_law','balears_general','balears_special','balears_proc'],
['Elegir régimen general o especial.','Evento en instalación pública o con público/ticketing.','Dudas sobre federación, licencias o actividad no federada.'])

add('CN','Canarias',['canarias','islas canarias'],
'Canarias regula el deporte por la Ley 1/2019 y su Registro de Entidades Deportivas funciona con procedimientos electrónicos.',[
('Registro','verified','El Registro autonómico inscribe entidades deportivas con sede en Canarias y referencia la Ley 1/2019.'),
('Tramitación electrónica','verified','El portal oficial indica que los procedimientos del Registro se tramitan exclusivamente de forma telemática para las personas jurídicas.'),
('Operaciones registrales','verified','Se publican trámites de inscripción, cuentas, reglamentos federativos, libros, cargos, estatutos, certificados y cancelación.'),
('Eventos e interclubs','case','Una entidad inscrita no obtiene por ello autorización automática para cualquier evento. Deben revisarse cabildo/ayuntamiento cuando corresponda, recinto, modalidad, seguros y régimen de espectáculo/actividad.')],
['canarias_law','canarias_reg'],
['Preparación de expediente electrónico del club.','Evento entre islas o con participantes de distintos territorios.','Velada con público, ticketing o menores.'])

add('CB','Cantabria',['cantabria'],
'Cantabria diferencia clubes elementales y básicos y vincula el reconocimiento jurídico-deportivo de los clubes a la inscripción registral.',[
('Tipos de club','verified','La normativa publicada distingue clubes deportivos elementales y básicos, además de otras figuras.'),
('Club básico','verified','La regulación publicada para clubes básicos exige acta fundacional otorgada ante notario por al menos cinco personas físicas y estatutos provisionales.'),
('Registro','verified','La inscripción en el Registro de Entidades Deportivas es requisito para reconocimiento legal/oficial del club y adquisición de personalidad jurídica como tal según la regulación publicada.'),
('Eventos e interclubs','case','Para eventos se debe verificar además recinto, ayuntamiento, federación/modalidad, seguros y normativa de espectáculos o actividad aplicable.')],
['cantabria_law','cantabria_clubs'],
['Elegir entre club elemental o básico.','Preparar constitución notarial de club básico.','Evento con público o dudas sobre oficialidad/federación.'])

add('CM','Castilla-La Mancha',['castilla-la mancha','castilla la mancha'],
'Castilla-La Mancha dispone de Ley 5/2015 y Registro de Entidades Deportivas propio; publica de forma expresa el mínimo de promotores para clubes.',[
('Club deportivo','verified','El portal oficial define los clubes como asociaciones privadas sin ánimo de lucro con personalidad jurídica propia y domicilio en un municipio de Castilla-La Mancha.'),
('Fundadores','verified','La constitución se formaliza mediante acta fundacional y el portal oficial fija un mínimo de cinco personas fundadoras.'),
('Registro','verified','La inscripción en el Registro autonómico es necesaria para el reconocimiento a efectos de la Ley 5/2015.'),
('Eventos e interclubs','case','La inscripción del club no sustituye autorizaciones de recinto, municipio ni reglas de la federación/modalidad. En deportes de contacto debe verificarse especialmente la clasificación de la actividad y las coberturas.')],
['clm_law','clm_clubs','clm_reg'],
['Constituir el club y preparar estatutos.','Evento con público o menores.','Actividad que se quiere presentar como oficial o computable en récord.'])

add('CL','Castilla y León',['castilla y leon','castilla y león'],
'Castilla y León regula la actividad físico-deportiva por Ley 3/2019 y mantiene un Registro autonómico de entidades.',[
('Registro','verified','El Registro inscribe federaciones, clubes, secciones y sociedades anónimas deportivas con domicilio en Castilla y León.'),
('Efectos','verified','La sede oficial indica que la inscripción es gratuita y requisito para optar a ayudas públicas y participar en competiciones deportivas oficiales.'),
('Actualizaciones','verified','El trámite contempla también modificaciones estatutarias, domicilio, composición directiva y disolución.'),
('Eventos e interclubs','case','Para una velada o interclub se deben añadir las comprobaciones del municipio/recinto, federación o modalidad, seguros y protección de menores cuando proceda.')],
['cyl_law','cyl_reg'],
['Alta registral y adaptación de estatutos.','Competición oficial o evento con varios clubes.','Uso de instalación municipal y condiciones de público/ticketing.'])

add('CT','Cataluña',['cataluna','cataluña','catalunya'],
'Cataluña dispone de Registro de Entidades Deportivas, normativa deportiva propia, régimen específico de actividades extraordinarias y protocolo autonómico de protección de menores.',[
('Registro','verified','El REE inscribe clubes y asociaciones deportivas con domicilio social en Cataluña y publica modelos y trámites de constitución/estatutos.'),
('Constitución','verified','La información oficial del REE utilizada por KOMBAX indica un mínimo de tres personas físicas con capacidad de obrar para constituir un club deportivo; debe verificarse el modelo vigente antes de presentar.'),
('Eventos extraordinarios','verified','Interior de la Generalitat publica un régimen específico para espectáculos y actividades recreativas extraordinarias, cuya autorización/licencia depende del supuesto y puede involucrar Generalitat o municipio.'),
('Menores','verified','Existe protocolo marco autonómico de protección de infancia y adolescencia frente a violencias en el ámbito deportivo, con edición revisada en 2025.'),
('Eventos e interclubs','case','Aunque exista información autonómica, debe validarse ordenanza municipal, condiciones del recinto, modalidad/federación, aforo, seguros y asistencia.')],
['cat_law','cat_reg','cat_club','cat_events','cat_minor'],
['Evento con público, menores o recinto no habitual.','Dudas sobre licencia/cobertura de participantes.','Constitución de club o actuación en varias comunidades.'])

add('VC','Comunitat Valenciana',['comunitat valenciana','comunidad valenciana','valencia'],
'La Comunitat Valenciana diferencia expresamente entre club deportivo, grupo de recreación deportiva y secciones de otras entidades.',[
('Marco vigente','verified','La Ley 2/2011 está consolidada con modificaciones publicadas hasta 2026 y debe consultarse en su versión vigente.'),
('Club deportivo','verified','El trámite autonómico define el club deportivo como asociación sin ánimo de lucro orientada a promoción/práctica de modalidades y participación en el ámbito federado.'),
('Recreación deportiva','verified','El mismo trámite distingue el grupo de recreación deportiva para práctica de actividad física o deporte al margen del ámbito federado, además de secciones en entidades no deportivas.'),
('Eventos e interclubs','case','La elección de entidad no determina por sí sola si un evento es federado, recreativo o espectáculo. Debe revisarse la actividad concreta, recinto, municipio, seguros y federación/modalidad.')],
['val_law','val_reg'],
['Elegir club federado, grupo recreativo o sección.','Evento mixto federado/no federado.','Velada con público, menores o venta de entradas.'])

add('EX','Extremadura',['extremadura'],
'Extremadura cuenta con Ley del Deporte y Registro General de Entidades Deportivas con varias categorías de entidades.',[
('Registro','verified','El Registro General de Entidades Deportivas tramita inscripción, modificación, certificación y cancelación.'),
('Tipos','verified','El portal oficial incluye clubes deportivos, sociedades anónimas deportivas, entidades de actividad físico-deportiva, agrupaciones deportivas escolares y federaciones.'),
('Efecto deportivo','verified','La sede autonómica indica que el registro otorga plenos derechos deportivos a las entidades extremeñas en los términos de su normativa.'),
('Eventos e interclubs','case','Para un evento deben verificarse de forma adicional municipio/recinto, federación o modalidad, seguro y eventual régimen de espectáculo/actividad.')],
['ext_law','ext_reg'],
['Elegir tipo de entidad.','Actividad con escolares/menores.','Evento con público o que pretende ser competición oficial.'])

add('GA','Galicia',['galicia','galiza'],
'Galicia dispone de Ley 3/2012 y Registro propio; destaca que el Registro ofrece un trámite específico para inscribir el protocolo de protección de niños, niñas y adolescentes frente a la violencia en el deporte.',[
('Registro','verified','La inscripción de entidades deportivas determina su reconocimiento legal y es requisito para participar en competiciones oficiales y para determinadas ayudas/asesoramiento autonómico.'),
('Tipos','verified','El procedimiento incluye clubes, agrupaciones deportivas escolares, secciones, federaciones y permite también determinadas entidades mercantiles en los términos publicados.'),
('Protección de menores','verified','Deporte Galego publica un trámite específico de inscripción del protocolo de protección de NNA frente a la violencia en el deporte.'),
('Eventos e interclubs','case','Para una velada deben añadirse comprobaciones de concello/recinto, modalidad/federación, seguros, público y protección de menores.')],
['gal_law','gal_reg','gal_proc'],
['Protocolos de menores.','Participación oficial y registro del club.','Evento con público, menores o deportistas de fuera de Galicia.'])

add('MD','Comunidad de Madrid',['madrid','comunidad de madrid'],
'Madrid mantiene Registro de Entidades Deportivas y distingue, entre otras figuras, clubes elementales y básicos.',[
('Tipos de entidad','verified','El registro autonómico contempla clubes deportivos elementales y básicos, agrupaciones, secciones, federaciones y otras figuras publicadas.'),
('Plazo de solicitud','verified','La sede oficial indica que la solicitud de inscripción debe presentarse en el plazo de 15 días desde el acta fundacional o documento similar.'),
('Tasa y resolución','verified','El trámite exige tasa; publica un plazo máximo de resolución de dos meses y efecto estimatorio del silencio para los supuestos indicados, salvo particularidades como federaciones.'),
('Eventos e interclubs','case','Para un evento se debe revisar además el ayuntamiento, el recinto, la modalidad/federación, seguros, aforo y régimen de espectáculo/actividad que corresponda.')],
['mad_law','mad_reg'],
['Elegir club elemental o básico.','Preparar alta dentro del plazo registral.','Velada con público, menores o ticketing.'])

add('MC','Región de Murcia',['murcia','region de murcia','región de murcia'],
'Murcia tiene Ley 8/2015 y un procedimiento registral específico para constitución de clubes, con modelos oficiales y efectos definidos.',[
('Registro y efectos','verified','La inscripción es necesaria para el reconocimiento oficial deportivo, acceso a derechos/beneficios autonómicos y solicitud de integración en la federación regional correspondiente.'),
('Documentación','verified','La sede exige acta fundacional y estatutos conforme a modelos oficiales, además de la documentación de identidad/representación aplicable.'),
('Tasa y resolución','verified','El procedimiento publica tasa general de inscripción, plazo de resolución de seis meses y silencio negativo.'),
('Eventos e interclubs','case','El alta de club no sustituye permisos de recinto/municipio ni reglas federativas. Deben revisarse también seguros, asistencia y protección de menores.')],
['mur_law','mur_reg'],
['Constituir y registrar club.','Integración federativa regional.','Evento con público, menores o dudas sobre permisos del recinto.'])

add('NC','Comunidad Foral de Navarra',['navarra','comunidad foral de navarra'],
'Navarra combina un Registro del Deporte renovado con una sección específica de profesionales y requisitos profesionales propios.',[
('Registro','verified','El Registro del Deporte incluye sección de entidades deportivas y sección de profesionales.'),
('Clubes','verified','La normativa foral de entidades deportivas establece acta fundacional y estatutos; la regulación histórica vigente utilizada por el Registro fija un mínimo de tres promotores para el club deportivo.'),
('Profesiones del deporte','verified','La inscripción es obligatoria para ejercer en Navarra determinadas profesiones reguladas: educación física, monitor/a, entrenador/a, dirección deportiva y preparación física, con las excepciones publicadas.'),
('Actualización 2025','verified','El portal oficial indica que las cualificaciones exigibles y el nuevo registro profesional operan en el marco de la Ley Foral 18/2019 y normativa de desarrollo de 2024-2025.'),
('Eventos e interclubs','case','En eventos debe verificarse además recinto/municipio, federación/modalidad, seguros y si el personal que interviene está sujeto a requisitos profesionales navarros.')],
['nav_law','nav_reg','nav_prof'],
['Revisión de titulaciones/profesionales.','Constitución de club.','Evento con personal técnico, menores o participantes externos.'])

add('PV','País Vasco / Euskadi',['pais vasco','país vasco','euskadi'],
'Euskadi cuenta con Ley deportiva de 2023 y un Registro de Entidades Deportivas de tramitación electrónica.',[
('Constitución de club','verified','El portal oficial establece acta fundacional por un mínimo de tres personas físicas o jurídicas con capacidad de obrar, con voluntad asociativa sin ánimo de lucro y fines deportivos.'),
('Tramitación','verified','Los trámites del Registro de Entidades Deportivas se realizan electrónicamente; el portal publica modelos para junta directiva u órgano unipersonal.'),
('Marco vigente','verified','La Ley 2/2023 sustituyó el marco autonómico anterior y es la referencia general actual de actividad física y deporte.'),
('Eventos e interclubs','case','Se debe verificar además territorio histórico/municipio cuando corresponda, recinto, modalidad/federación, seguros y condiciones de público/menores.')],
['pv_law','pv_reg'],
['Elección de modelo de gobierno del club.','Evento en varios territorios históricos.','Velada con público, menores o dudas federativas.'])

add('RI','La Rioja',['la rioja','rioja'],
'La Rioja regula el ejercicio físico y el deporte mediante Ley 1/2015 y mantiene un Registro General de Entidades Deportivas.',[
('Club deportivo','verified','El trámite define el club como asociación privada sin ánimo de lucro con personalidad jurídica y capacidad de obrar, formada por personas físicas, orientada a ejercicio físico, práctica/promoción deportiva y competición.'),
('Registro','verified','La inscripción se exige a clubes con domicilio social en La Rioja y es requisito previo para determinadas subvenciones, ayudas, reconocimientos y convenios con la Comunidad Autónoma.'),
('Tramitación','verified','El procedimiento admite gestión electrónica con certificado y está vinculado al Registro General de Entidades Deportivas.'),
('Eventos e interclubs','case','Para eventos deben verificarse ayuntamiento/recinto, modalidad/federación, seguros y régimen de actividad/espectáculo aplicable.')],
['rio_law','rio_reg'],
['Constitución e inscripción de club.','Evento con ayudas públicas o convenio.','Velada con público, menores o ticketing.'])

add('CE','Ceuta',['ceuta','ciudad autonoma de ceuta','ciudad autónoma de ceuta'],
'Ceuta dispone de reglamentos propios de asociaciones deportivas y de su Registro General de Asociaciones Deportivas.',[
('Registro','verified','El RGAD inscribe federaciones, clubes y entidades deportivas con sede en Ceuta; la inscripción es requisito para reconocimiento y para determinadas ayudas/convenios de la Ciudad.'),
('Tipos de club','verified','La regulación local distingue clubes deportivos elementales y básicos.'),
('Competición oficial','verified','La normativa local publicada indica que para participar en actividades y competiciones oficiales los clubes deben afiliarse a la federación ceutí correspondiente.'),
('Plazo registral','verified','El reglamento del Registro publicado establece presentación de solicitud/documentos dentro de los 15 días desde el acta fundacional y prevé estimación por silencio a los tres meses para los supuestos indicados, con excepción de federaciones.'),
('Eventos e interclubs','case','Debe verificarse adicionalmente recinto, actividad/licencia local, federación, seguros y condiciones de público/menores.')],
['ceuta_reg','ceuta_club'],
['Elegir club elemental o básico.','Afiliación para competición oficial.','Evento con público o necesidad de licencia de actividad/recinto.'])

add('ML','Melilla',['melilla','ciudad autonoma de melilla','ciudad autónoma de melilla'],
'Melilla mantiene un Registro de entidades, clubes y asociaciones deportivas y reglamentos propios publicados por la Ciudad Autónoma.',[
('Registro','verified','La Sede de Melilla publica un trámite específico para registrar entidades, clubes y asociaciones deportivas, gestionado por la Dirección General de Deportes.'),
('Documentación','verified','El procedimiento publicado exige solicitud según modelo, acta de constitución, estatutos y DNI de integrantes, además de representación cuando proceda.'),
('Normativa local','verified','El BOME Extraordinario 20 de 25/06/1999 recoge el Reglamento del Registro, el de Federaciones Deportivas y el de Asociaciones Deportivas de la Ciudad Autónoma.'),
('Competición oficial','verified','La regulación publicada para clubes elementales establece inscripción registral y afiliación a la federación deportiva correspondiente para participar en competición oficial.'),
('Eventos e interclubs','case','Para organizar eventos deben verificarse además instalación, autorizaciones/condiciones locales, federación/modalidad, seguros, público y menores.')],
['mel_reg','mel_bome'],
['Constitución y alta del club.','Participación en competición oficial.','Evento con público, menores o necesidad de revisar autorizaciones locales.'])

# Sanity: 19 territory units (17 comunidades + Ceuta + Melilla)
assert len(T)==19, len(T)

def slug(s):
    s=''.join(c for c in unicodedata.normalize('NFD',s) if unicodedata.category(c)!='Mn')
    return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')

# Write source matrix
with open(SRC/'TERRITORIAL_SOURCES_MATRIX.md','w',encoding='utf-8') as f:
    f.write('# KOMBAX Guías - Matriz de fuentes territoriales\n\n')
    f.write(f'**Revisión:** {REVIEW}\n\nSolo se incorporan fuentes oficiales de administraciones públicas, boletines oficiales o sedes electrónicas.\n\n')
    for k,(title,org,url) in S.items():
        f.write(f'- **{k}** - {title} - {org}: {url}\n')

# markdown files
for t in T:
    p=SRC/f"{t['code']}_{slug(t['name'])}.md"
    with open(p,'w',encoding='utf-8') as f:
        f.write(f"# KOMBAX Guías - {t['name']}\n\n")
        f.write(f"**Capa territorial diferencial** · Revisión: {REVIEW}\n\n")
        f.write('> Esta ficha complementa las 15 guías estatales. No sustituye la lectura de la norma vigente ni una revisión profesional del caso concreto. KOMBAX no rellena huecos normativos con supuestos.\n\n')
        f.write('## Qué aporta esta capa\n\n'+t['summary']+'\n\n')
        f.write('## Marco común que no se repite\n\n')
        for x in COMMON: f.write(f'- {x}\n')
        f.write('\n## Diferencias verificadas y puntos de control\n\n')
        for area,status,text in t['differentials']:
            label={'verified':'DIFERENCIAL VERIFICADO','case':'REQUIERE VERIFICACIÓN DEL CASO','common':'MARCO COMÚN'}[status]
            f.write(f'### {area}\n\n**{label}.** {text}\n\n')
        f.write('## Cuándo abrir KOMBAX Consultoría\n\n')
        for x in t['consult']: f.write(f'- {x}\n')
        f.write('\n**La consultoría puede ayudar a:** clasificar el supuesto, localizar organismo y trámite competentes, revisar documentación, cruzar normativa autonómica/municipal/federativa y señalar los puntos que deben validar profesionales jurídicos, fiscales, laborales, sanitarios o técnicos cuando proceda.\n\n')
        f.write('## Fuentes oficiales\n\n')
        for k in t['sources']:
            title,org,url=S[k]; f.write(f'- {title} - {org}: {url}\n')
        f.write('\n## Límite de publicación\n\nNo se publican como universales importes, tasas, plazos municipales, seguros, requisitos sanitarios, permisos de recinto ni condiciones federativas cuando dependen del supuesto. Se muestran como verificación específica y se derivan, si el usuario lo necesita, al flujo de KOMBAX Consultoría.\n')

# JSON search index
catalog={
 'review_date':REVIEW,
 'scope':'España - 17 comunidades autónomas + Ceuta + Melilla',
 'policy':{
   'no_invention':True,
   'statuses':{
      'verified':'Diferencial territorial soportado por fuente oficial',
      'case':'No existe una respuesta universal publicada en esta capa; verificar municipio/recinto/federación/caso',
      'common':'Marco estatal ya cubierto por las 15 guías base'
   },
   'consulting_boundary':'KOMBAX Consultoría se ofrece cuando la respuesta depende de datos concretos del caso; no sustituye a profesionales sujetos a reserva o habilitación legal.'
 },
 'territories':[],'sources':{k:{'title':v[0],'organization':v[1],'url':v[2]} for k,v in S.items()}
}
for t in T:
    catalog['territories'].append({
      'code':t['code'],'name':t['name'],'slug':slug(t['name']),'aliases':t['aliases'],'summary':t['summary'],
      'differentials':[{'area':a,'status':s,'text':x} for a,s,x in t['differentials']],
      'consulting_triggers':t['consult'],'source_keys':t['sources'],
      'source_count':len(t['sources']),
      'verified_items':sum(1 for _,s,_ in t['differentials'] if s=='verified'),
      'case_specific_items':sum(1 for _,s,_ in t['differentials'] if s=='case')
    })
with open(OUT/'KOMBAX_TERRITORIAL_CATALOG_2026.json','w',encoding='utf-8') as f: json.dump(catalog,f,ensure_ascii=False,indent=2)
with open(SRC/'territories_index.json','w',encoding='utf-8') as f: json.dump(catalog,f,ensure_ascii=False,indent=2)

# matrix for future UI/filtering
matrix=[]
for t in T:
    for area,status,text in t['differentials']:
        matrix.append({'territory_code':t['code'],'territory':t['name'],'area':area,'status':status,'text':text,'source_keys':t['sources']})
with open(OUT/'KOMBAX_TERRITORIAL_DIFFERENTIAL_MATRIX_2026.json','w',encoding='utf-8') as f: json.dump({'review_date':REVIEW,'rows':matrix},f,ensure_ascii=False,indent=2)

# PDF styles
PAGE_W,PAGE_H=A4
C_DARK=colors.HexColor('#090B10'); C_RED=colors.HexColor('#F04452'); C_CYAN=colors.HexColor('#37D6E8'); C_TEXT=colors.HexColor('#192230'); C_MUTED=colors.HexColor('#64748B'); C_SOFT=colors.HexColor('#F5F7FA'); C_AMBER=colors.HexColor('#F5C267')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='KTerrTitle',fontName='DejaVu-Bold',fontSize=24,leading=28,textColor=colors.white,spaceAfter=8))
styles.add(ParagraphStyle(name='KTerrSub',fontName='DejaVu',fontSize=10.5,leading=15,textColor=colors.HexColor('#C7D0DD'),spaceAfter=8))
styles.add(ParagraphStyle(name='KTerrH',fontName='DejaVu-Bold',fontSize=14,leading=18,textColor=C_RED,spaceBefore=10,spaceAfter=6))
styles.add(ParagraphStyle(name='KTerrBody',fontName='DejaVu',fontSize=9.1,leading=13.2,textColor=C_TEXT,spaceAfter=6))
styles.add(ParagraphStyle(name='KTerrSmall',fontName='DejaVu',fontSize=7.2,leading=9.6,textColor=C_MUTED,spaceAfter=3))
styles.add(ParagraphStyle(name='KTerrTagV',fontName='DejaVu-Bold',fontSize=8.2,leading=10,textColor=colors.HexColor('#0F766E')))
styles.add(ParagraphStyle(name='KTerrTagC',fontName='DejaVu-Bold',fontSize=8.2,leading=10,textColor=colors.HexColor('#92400E')))

def footer(canvas,doc):
    canvas.saveState(); canvas.setFont('DejaVu',7); canvas.setFillColor(colors.HexColor('#6B7280'))
    canvas.drawString(18*mm,9*mm,f'KOMBAX Guías · Capa territorial · {REVIEW}')
    canvas.drawRightString(PAGE_W-18*mm,9*mm,str(doc.page)); canvas.restoreState()

def cover(t):
    story=[]
    if HERO.exists(): story += [Image(str(HERO),width=174*mm,height=97.9*mm),Spacer(1,4*mm)]
    data=[[Paragraph('KOMBAX GUÍAS · TERRITORIOS',ParagraphStyle('tagx',fontName='DejaVu-Bold',fontSize=9,textColor=C_CYAN))],
          [Paragraph(t['name'],styles['KTerrTitle'])],
          [Paragraph('Normativa diferencial · registro · clubes · puntos de control · acceso a consultoría',styles['KTerrSub'])],
          [Paragraph(f'Revisión: {REVIEW}',ParagraphStyle('revx',fontName='DejaVu',fontSize=8,textColor=colors.HexColor('#AAB4C3')))]]
    tb=Table(data,colWidths=[174*mm]); tb.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),C_DARK),('LEFTPADDING',(0,0),(-1,-1),8*mm),('RIGHTPADDING',(0,0),(-1,-1),8*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    story += [tb,Spacer(1,4*mm)]
    warn=Table([[Paragraph('<b>Principio editorial:</b> esta ficha no completa huecos con conjeturas. Si el requisito depende de ayuntamiento, recinto, modalidad, federación, aforo, participante o actividad concreta, se marca como verificación específica.',styles['KTerrBody'])]],colWidths=[174*mm])
    warn.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFF8E8')),('BOX',(0,0),(-1,-1),0.7,C_AMBER),('LEFTPADDING',(0,0),(-1,-1),5*mm),('RIGHTPADDING',(0,0),(-1,-1),5*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    story += [warn,PageBreak()]
    return story

def build_pdf(t,path):
    doc=SimpleDocTemplate(str(path),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=16*mm,bottomMargin=16*mm,author='KOMBAX Spain',title=f"KOMBAX Guías - {t['name']}")
    st=cover(t)
    st += [Paragraph('Qué aporta esta capa',styles['KTerrH']),Paragraph(t['summary'],styles['KTerrBody'])]
    st += [Paragraph('Marco común',styles['KTerrH'])]
    for x in COMMON: st.append(Paragraph('• '+x,styles['KTerrBody']))
    st += [Paragraph('Diferencias verificadas y puntos de control',styles['KTerrH'])]
    for area,status,text in t['differentials']:
        tag='DIFERENCIAL VERIFICADO' if status=='verified' else 'REQUIERE VERIFICACIÓN DEL CASO'
        sty=styles['KTerrTagV'] if status=='verified' else styles['KTerrTagC']
        box=Table([[Paragraph(area,ParagraphStyle('a',fontName='DejaVu-Bold',fontSize=10.2,textColor=C_TEXT)),Paragraph(tag,sty)]],colWidths=[100*mm,74*mm])
        box.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),C_SOFT),('BOX',(0,0),(-1,-1),0.4,colors.HexColor('#CBD5E1')),('LEFTPADDING',(0,0),(-1,-1),4*mm),('RIGHTPADDING',(0,0),(-1,-1),4*mm),('TOPPADDING',(0,0),(-1,-1),2.5*mm),('BOTTOMPADDING',(0,0),(-1,-1),2.5*mm),('VALIGN',(0,0),(-1,-1),'MIDDLE')]))
        st += [box,Spacer(1,1.5*mm),Paragraph(text,styles['KTerrBody']),Spacer(1,1.5*mm)]
    st += [Paragraph('Cuándo abrir KOMBAX Consultoría',styles['KTerrH'])]
    for x in t['consult']: st.append(Paragraph('• '+x,styles['KTerrBody']))
    call=Table([[Paragraph('<b>Qué aporta la consulta:</b> clasificación del caso, identificación de organismo/trámite, revisión documental, cruce de normativa autonómica/municipal/federativa y señalamiento de validaciones profesionales externas cuando correspondan.',styles['KTerrBody'])]],colWidths=[174*mm])
    call.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFF0F2')),('BOX',(0,0),(-1,-1),0.7,C_RED),('LEFTPADDING',(0,0),(-1,-1),5*mm),('RIGHTPADDING',(0,0),(-1,-1),5*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    st += [call,Paragraph('Fuentes oficiales',styles['KTerrH'])]
    for k in t['sources']:
        title,org,url=S[k]; st.append(Paragraph(f'<b>{title}</b> · {org}<br/><font size="7">{url}</font>',styles['KTerrSmall']))
    st += [Paragraph('Límite de publicación',styles['KTerrH']),Paragraph('KOMBAX no publica como universales importes, tasas, plazos municipales, seguros, requisitos sanitarios, permisos de recinto ni condiciones federativas cuando dependen del supuesto. Antes de ejecutar una actuación real, debe comprobarse que la normativa, trámite y reglamento siguen vigentes.',styles['KTerrBody'])]
    doc.build(st,onFirstPage=footer,onLaterPages=footer)

pdfs=[]
for t in T:
    p=OUT/f"KOMBAX_GUIAS_TERRITORIO_{t['code']}_{slug(t['name']).upper().replace('-','_')}.pdf"
    build_pdf(t,p); pdfs.append(p)

# master territorial dossier
master=OUT/'KOMBAX_GUIAS_TERRITORIOS_ESPANA_2026.pdf'
doc=SimpleDocTemplate(str(master),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=16*mm,bottomMargin=16*mm,author='KOMBAX Spain',title='KOMBAX Guías - Dossier territorial España 2026')
intro={'name':'España · 19 territorios'}
st=cover(intro)
st += [Paragraph('Cómo usar este dossier',styles['KTerrH']),Paragraph('Complementa las 15 guías temáticas de KOMBAX con la información diferencial verificada de las 17 comunidades autónomas y las ciudades autónomas de Ceuta y Melilla. La capa territorial no sustituye el marco estatal: evita repetirlo y destaca únicamente lo que cambia o lo que exige una comprobación local.',styles['KTerrBody']),Paragraph('Territorios incluidos',styles['KTerrH'])]
for i,t in enumerate(T,1): st.append(Paragraph(f'{i:02d}. {t["name"]}',styles['KTerrBody']))
st.append(PageBreak())
for i,t in enumerate(T):
    st += [Paragraph(t['name'],ParagraphStyle('mtt',fontName='DejaVu-Bold',fontSize=20,leading=24,textColor=C_TEXT,spaceAfter=6)),Paragraph(t['summary'],styles['KTerrBody'])]
    for area,status,text in t['differentials']:
        tag='VERIFICADO' if status=='verified' else 'CASO ESPECÍFICO'
        st.append(Paragraph(f'<b>{area} · {tag}</b><br/>{text}',styles['KTerrBody']))
    st += [Paragraph('Derivación a Consultoría',styles['KTerrH'])]
    for x in t['consult']: st.append(Paragraph('• '+x,styles['KTerrBody']))
    st += [Paragraph('Fuentes',styles['KTerrH'])]
    for k in t['sources']:
        title,org,url=S[k]; st.append(Paragraph(f'{title} · {org}<br/><font size="7">{url}</font>',styles['KTerrSmall']))
    if i<len(T)-1: st.append(PageBreak())
doc.build(st,onFirstPage=footer,onLaterPages=footer)

# Human-readable matrix
with open(SRC/'TERRITORIAL_DIFFERENTIAL_MATRIX.md','w',encoding='utf-8') as f:
    f.write('# KOMBAX Guías - Matriz diferencial territorial\n\n')
    f.write(f'**Revisión:** {REVIEW}\n\n')
    f.write('| Territorio | Diferenciales verificados | Puntos caso específico | Fuentes |\n|---|---:|---:|---:|\n')
    for t in T:
        v=sum(1 for _,s,_ in t['differentials'] if s=='verified'); c=sum(1 for _,s,_ in t['differentials'] if s=='case')
        f.write(f"| {t['name']} | {v} | {c} | {len(t['sources'])} |\n")

print(f'Generated {len(T)} territorial markdown files, {len(pdfs)} individual PDFs and master: {master}')
