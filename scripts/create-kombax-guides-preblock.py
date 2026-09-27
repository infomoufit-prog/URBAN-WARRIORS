from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, KeepTogether, Image
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import mm
from pathlib import Path
import json, textwrap, os, re, hashlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'/'guides'
SRC=ROOT/'docs'/'09_GUIDES_SOURCE'
OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(parents=True,exist_ok=True)
REVIEW='21/09/2026'
GUIDES_HERO=ROOT/'artifacts'/'assets'/'kombax-guides-hero.webp'

pdfmetrics.registerFont(TTFont('DejaVu','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Bold','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))

sources={
'ley_deporte':('Ley 39/2022, de 30 de diciembre, del Deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2022-24430'),
'csd_ley':('Ley del Deporte - marco y legislación deportiva','Consejo Superior de Deportes','https://www.csd.gob.es/es/csd/legislacion-deportiva/ley-del-deporte'),
'csd_licencias':('Licencias deportivas y estadísticas federativas','Consejo Superior de Deportes','https://www.csd.gob.es/es/federaciones-y-asociaciones/federaciones-deportivas-espanolas/licencias'),
'rd_seguro':('Real Decreto 849/1993 - prestaciones mínimas del Seguro Obligatorio Deportivo','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1993-16129'),
'lopiv':('Ley Orgánica 8/2021 - protección integral de infancia y adolescencia frente a la violencia','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2021-9347'),
'lopdgdd':('Ley Orgánica 3/2018 - protección de datos y derechos digitales','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2018-16673'),
'consumidores':('RDL 1/2007 - Ley General para la Defensa de los Consumidores y Usuarios','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2007-20555'),
'violencia':('Ley 19/2007 - violencia, racismo, xenofobia e intolerancia en el deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2007-13408'),
'rd203':('Real Decreto 203/2010 - Reglamento de prevención de violencia en el deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2010-3904'),
'patrocinio':('Ley 34/1988, General de Publicidad - contrato de patrocinio','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1988-26156'),
'mecenazgo':('Ley 49/2002 - régimen fiscal de entidades sin fines lucrativos e incentivos al mecenazgo','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2002-25039'),
'deportistas_prof':('Real Decreto 1006/1985 - relación laboral especial de deportistas profesionales','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1985-12313'),
'extranjeria':('Real Decreto 1155/2024 - Reglamento de extranjería','BOE','https://www.boe.es/eli/es/rd/2024/11/19/1155'),
'inclusion_trabajo':('Autorización inicial de residencia temporal y trabajo por cuenta ajena','Ministerio de Inclusión, Seguridad Social y Migraciones','https://www.inclusion.gob.es/web/migraciones/w/autorizacion-inicial-de-residencia-temporal-y-trabajo-por-cuenta-ajena-hi-16-'),
'inclusion_excepcion':('Residencia temporal con excepción a la autorización de trabajo','Ministerio de Inclusión, Seguridad Social y Migraciones','https://www.inclusion.gob.es/es/web/migraciones/w/aa-plantilla-hoja-informativa-no-borrar-duplicado-1'),
'aeat_iva_deporte':('IVA - exenciones sociales, culturales y deportivas','Agencia Tributaria','https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-practicos/manual-iva-2025/capitulo-03-entregas-realizadas-empresarios-profesionales/entregas-bienes-servic-realizadas-empresarios-profesionales/operaciones-exentas/exenciones-operaciones-interiores/exenciones-sociales-culturales-deportivas.html'),
'aeat_is':('Impuesto sobre Sociedades - entidades parcialmente exentas','Agencia Tributaria','https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-practicos/folleto-actividades-economicas/4-impuesto-sobre-sociedades.html'),
'aeat_actividad':('Manual de actividades económicas','Agencia Tributaria','https://sede.agenciatributaria.gob.es/Sede/informacion-institucional/sobre-agencia-tributaria/Manual_de_actividades_economicas.html'),
'gencat_ree':("Registre d'Entitats Esportives",'Generalitat de Catalunya - Esport','https://esport.gencat.cat/ca/arees_dactuacio/entitats-esportives/registre-dentitats-esportives-ree'),
'gencat_tramite_club':('Inscripción en el Registro de Entidades Deportivas','Tràmits Gencat','https://tramits.gencat.cat/es/tramits/tramits-temes/21441-Inscripcio-al-Registre-dEntitats-Esportives?moda=1'),
'gencat_normativa_entitats':("Normativa d'entitats esportives",'Generalitat de Catalunya - Esport','https://esport.gencat.cat/ca/arees_dactuacio/entitats-esportives/normativa-entitats-esportives'),
'gencat_seguro':('Normativa deportiva - licencias y seguros en actividades deportivas','Generalitat de Catalunya - Esport','https://esport.gencat.cat/ca/SG_Esport/consell-catala-de-lesport/preguntes-frequents/normativa-esportiva/'),
'gencat_eventos':('Espectáculos públicos y actividades recreativas de carácter extraordinario','Generalitat de Catalunya - Interior','https://interior.gencat.cat/es/arees_dactuacio/espectacles/espectacles_i_activitats_caracter_extraordinari/'),
'gencat_consum':('Compra de entradas por internet','Agència Catalana del Consum','https://consum.gencat.cat/ca/detalls/noticia/Compra-entrades-per-internet'),
'gencat_distancia':('Compras a distancia o fuera de establecimiento','Agència Catalana del Consum','https://consum.gencat.cat/ca/els-meus-drets/modalitats-de-compra/'),
'csd_menores':('Protocolo de actuación contra la violencia en Centros de Alto Rendimiento','Consejo Superior de Deportes','https://www.csd.gob.es/es/igualdad-en-el-deporte/protocolo-de-actuacion-contra-la-violencia-en-los-centros-de-alto-rendimiento-del-csd'),
'aepd_default':('Protección de datos por defecto','Agencia Española de Protección de Datos','https://www.aepd.es/derechos-y-deberes/cumple-tus-deberes/medidas-de-cumplimiento/proteccion-de-datos-por-defecto'),
'aepd_dpd_fed':('Federaciones deportivas y obligación de DPD cuando tratan datos de menores','Agencia Española de Protección de Datos','https://www.aepd.es/preguntas-frecuentes/10-menores-y-educacion/FAQ-1012-estan-obligadas-las-federaciones-deportivas-nombrar-una-persona-que-ejerza-dpd'),
'aepd_images':('Imágenes y vídeos en eventos con menores - criterios de información y difusión','Agencia Española de Protección de Datos','https://www.aepd.es/preguntas-frecuentes/10-menores-y-educacion/FAQ-1004-se-pueden-tomar-imagenes-o-grabar-videos-en-eventos-escolares'),
'gencat_minor_protocol':("Protocol marc de protecció d'infants i adolescents davant les violències en l'àmbit esportiu - 2a edició revisada febrer 2025",'Generalitat de Catalunya - Esport','https://esport.gencat.cat/web/.content/home/secretaria_general_de_lesport/Consell_Catala_Esport/normativa/acord_gov_23_protocol_proteccio_violencia.pdf'),
'aeat_partial_current':('Entidades parcialmente exentas - Impuesto sobre Sociedades','Agencia Tributaria','https://sede.agenciatributaria.gob.es/Sede/impuesto-sobre-sociedades/tienes-que-presentar-declaracion-impuesto-sociedades/entidades-parcialmente-exentas.html'),
'inclusion_sheets':('Hojas informativas de extranjería - buscador oficial','Ministerio de Inclusión, Seguridad Social y Migraciones','https://www.inclusion.gob.es/es/web/migraciones/hojas-informativas'),
'gencat_pau':('Preguntas frecuentes sobre el Decreto de medidas de autoprotección','Generalitat de Catalunya - Interior','https://interior.gencat.cat/es/arees_dactuacio/proteccio_civil/paus_hermes/preguntes_freq_sobre_decret_pau/'),
}

G=[]
def add(n,title,subtitle,scope,summary,legal,steps,checklist,example,consult,skeys,notes=None):
    G.append(dict(n=n,title=title,subtitle=subtitle,scope=scope,summary=summary,legal=legal,steps=steps,checklist=checklist,example=example,consult=consult,sources=skeys,notes=notes or []))

add(1,'Crear un club o asociación deportiva','De la idea a una entidad deportiva formalmente organizada','España - marco general; capa práctica desarrollada para Cataluña',
'Crear un club no es solo elegir un nombre. Hay que identificar la forma jurídica y deportiva adecuada, aprobar reglas internas, constituir los órganos de gobierno y realizar las inscripciones y trámites que correspondan. En España la regulación concreta de los clubes y registros deportivos es, en gran medida, autonómica.',
[
'La Ley 39/2022 establece el marco estatal del deporte, pero la constitución y registro ordinario de clubes se desarrolla por normativa autonómica.',
'En Cataluña, el Registro de Entidades Deportivas (REE) inscribe clubes y asociaciones deportivas con domicilio social en Cataluña; la inscripción comporta reconocimiento legal a efectos de la legislación deportiva catalana.',
'El trámite catalán publica modelos de acta de constitución y estatutos, tanto de régimen general como simplificado, y exige sede en Cataluña. No se debe reutilizar automáticamente este procedimiento en otra comunidad autónoma.',
'Una entidad sin ánimo de lucro puede tener obligaciones fiscales y censales aunque su finalidad no sea repartir beneficios. El tratamiento fiscal depende de la actividad y del tipo de entidad.'
],
['Definir finalidad, modalidad/es deportivas y ámbito territorial.','Comprobar el registro deportivo competente en la comunidad autónoma.','Preparar acta fundacional y estatutos adecuados a la normativa territorial.','Designar el órgano de gobierno y documentar aceptación de cargos.','Inscribir la entidad en el registro deportivo correspondiente.','Solicitar NIF y revisar obligaciones censales, contables y fiscales.','Revisar afiliación federativa si se quiere participar en competiciones oficiales.','Implantar protección de datos y, si hay menores de forma habitual, medidas de protección infantil.'],
['Nombre y disponibilidad comprobados','Acta fundacional','Estatutos','Junta/órgano de gobierno','Domicilio social','Registro deportivo competente','NIF y situación censal','Cuenta bancaria y reglas de firma','Seguro y licencias cuando procedan','Protocolo de menores si aplica'],
'Un grupo quiere abrir un club de Muay Thai en Girona. La guía permite preparar la estructura del club y localizar el REE catalán, pero no debe asumir qué federación o licencia concreta es obligatoria para cada actividad: eso depende de la modalidad, del tipo de competición y de la organización federativa aplicable.',
['La entidad tendrá actividad económica relevante o personal contratado.','Hay dudas entre club deportivo, asociación general, empresa u otra forma jurídica.','Se quiere competir oficialmente en varias disciplinas o federaciones.','La entidad operará en más de una comunidad autónoma o fuera de España.'],
['ley_deporte','gencat_ree','gencat_tramite_club','gencat_normativa_entitats','aeat_actividad','aeat_is'])

add(2,'Organizar un evento de deportes de contacto','Permisos, recinto, participantes, seguridad y operativa','España - marco general; capa práctica desarrollada para Cataluña',
'La autorización de un evento no puede resolverse con una lista universal. Cambian la comunidad autónoma, el municipio, el recinto, el aforo, la modalidad deportiva, el carácter oficial o no oficial, la presencia de menores, la venta de entradas y la participación de deportistas extranjeros.',
[
'El organizador debe identificar primero el régimen administrativo aplicable al espectáculo o actividad y al recinto. En Cataluña, Interior distingue los espectáculos/actividades extraordinarios y explica qué supuestos dependen de autorización de la Generalitat o licencia municipal.',
'La propia Generalitat advierte de que los espectáculos deportivos esporádicos pueden quedar exentos de tramitar licencia en ciertos supuestos, salvo que la normativa municipal disponga lo contrario; esa excepción no elimina el cumplimiento de las demás condiciones exigibles.',
'Las obligaciones de seguro deportivo y responsabilidad civil no deben confundirse: una cosa es la cobertura de participantes y otra la responsabilidad del organizador frente a público y terceros.',
'Las competiciones oficiales y los eventos incluidos en regímenes especiales de seguridad pueden tener obligaciones adicionales de acceso, entradas, seguridad y prevención de violencia.'
],
['Clasificar el evento: oficial/no oficial, federado/no federado, profesional/aficionado, con/sin público.','Identificar comunidad autónoma y municipio.','Confirmar licencia/autorización/comunicación aplicable al recinto y actividad.','Revisar aforo, evacuación, incendios, emergencias y condiciones técnicas del recinto.','Comprobar cobertura de participantes y responsabilidad civil.','Validar licencias, categorías, pesajes, reglas y personal arbitral con la organización deportiva competente.','Definir política de menores, imagen y protección de datos.','Si hay entradas, preparar condiciones de venta, precio final y protocolo de cancelación.','Si hay extranjeros, revisar entrada, estancia/trabajo y normativa federativa.','Cerrar plan de personal, acceso, incidencias, asistencia sanitaria y documentación de cierre.'],
['Ficha jurídica del organizador','Contrato/cesión del recinto','Régimen municipal/autonómico verificado','Aforo y plan de emergencia','Seguros','Reglamento deportivo aplicable','Lista de participantes/licencias','Personal arbitral/técnico','Protección de menores','Ticketing y condiciones de venta','Protección de datos e imagen','Plan de seguridad y acceso','Plan sanitario según exigencias aplicables','Plan de cancelación/reembolso'],
'Un promotor quiere hacer una velada de 700 personas en un pabellón municipal de Barcelona con menores en combates amateur y deportistas de fuera de la UE. Esa combinación exige una revisión concreta del recinto, ordenanza municipal, modalidad/federación, protección del menor y situación de cada participante extranjero; no debe resolverse con una guía genérica.',
['Evento con público numeroso o recinto no habitual.','Menores compitiendo.','Deportistas extranjeros.','Evento profesional o con premios/bolsas.','Venta de entradas y política compleja de devolución.','Dudas sobre si es competición oficial, interclub, exhibición o espectáculo extraordinario.'],
['ley_deporte','gencat_eventos','gencat_seguro','violencia','rd203','lopiv','consumidores','gencat_consum'])

add(3,'Organizar un interclub','Encuentro deportivo entre clubes sin convertirlo en una competición mal clasificada','España - marco general; Cataluña como primera capa autonómica',
'“Interclub” es una denominación de uso deportivo, no una categoría jurídica universal. Antes de organizarlo hay que determinar qué es realmente: entrenamiento conjunto, actividad federada, competición, exhibición, actividad abierta al público o espectáculo deportivo.',
[
'La etiqueta “interclub” no sustituye la clasificación jurídica o federativa de la actividad.',
'En Cataluña, las entidades que organizan actividades físicas o deportivas deben atender a las reglas de licencia/cobertura aplicables a participantes; la administración deportiva publica obligaciones específicas sobre licencias y seguros.',
'Si la actividad se abre al público o se celebra en condiciones distintas a las autorizadas para el recinto, puede entrar en el régimen de espectáculos/actividades extraordinarios y debe verificarse el supuesto concreto.',
'Con menores de edad hay obligaciones reforzadas de protección y protocolos cuando la entidad realiza actividades con menores de forma habitual.'
],
['Definir por escrito el formato real del interclub.','Identificar clubes organizadores y responsable jurídico principal.','Confirmar con la federación/organización deportiva si requiere autorización, licencia o comunicación.','Verificar cobertura de todos los participantes.','Fijar reglas deportivas, categorías, protecciones y criterios de parada.','Establecer personal técnico/arbitral y respuesta sanitaria adecuada al formato.','Revisar recinto, aforo y presencia de público.','Gestionar menores, autorizaciones e imagen.','Documentar incidencias y resultados si se publican.'],
['Responsable organizador','Formato clasificado','Participantes identificados','Licencias/coberturas verificadas','Reglas y protecciones','Recinto y aforo','Plan sanitario','Menores protegidos','Consentimientos de imagen cuando procedan','Registro de incidencias'],
'Un gimnasio invita a tres clubes a hacer sparring técnico sin público. Otro vende 300 entradas y anuncia combates con ganadores. Aunque ambos usen la palabra “interclub”, el segundo puede activar requisitos jurídicos, administrativos y federativos muy distintos.',
['No está claro si el evento cuenta como competición.','Se cobrará entrada.','Habrá menores.','Participan clubes de otra comunidad o país.','Se quieren publicar resultados como récord oficial.'],
['gencat_seguro','gencat_eventos','lopiv','ley_deporte'])

add(4,'Licencias deportivas: alta, renovación y gestión','Qué habilita una licencia y por qué depende de modalidad, ámbito y federación','España - marco estatal y cautelas autonómicas/federativas',
'No existe una “licencia KOMBAX” que sustituya a la licencia deportiva oficial. KOMBAX puede gestionar datos, vencimientos y documentación, pero la expedición y los efectos deportivos corresponden a la organización competente.',
[
'La Ley 39/2022 exige licencia de la federación deportiva correspondiente para participar en actividades o competiciones oficiales de ámbito estatal e internacional, con las reglas de integración previstas para federaciones autonómicas.',
'La licencia no tiene un precio ni requisitos únicos para todas las modalidades. Categoría, estamento, edad, reconocimiento médico, seguros y documentación pueden variar.',
'El CSD publica información sobre licencias y federaciones, pero el alta concreta debe verificarse ante la federación aplicable.',
'En Cataluña, la normativa de entidades deportivas vincula licencias de actividad física/deportivas y seguros a la organización de actividades en determinados supuestos.'
],
['Identificar modalidad, disciplina y ámbito territorial.','Determinar si la actividad es oficial y qué federación la reconoce.','Consultar requisitos vigentes de la federación antes de pedir documentación al deportista.','Separar datos de licencia, seguro, reconocimiento/aptitud y documentos personales.','Registrar fecha de alta, vigencia, estado y motivo de baja/renovación.','No marcar una licencia como “válida” solo por tener un número: debe comprobarse el emisor y vigencia.'],
['Federación emisora','Modalidad/disciplina','Categoría/estamento','Número de licencia','Fecha de vigencia','Seguro asociado','Requisitos médicos si existen','Documentación aportada','Estado verificado','Fecha de próxima revisión'],
'Un competidor tiene licencia autonómica de una disciplina y quiere participar en un campeonato estatal de otra. No debe suponerse que la misma licencia sirve: hay que comprobar integración, modalidad y reglamento de la competición.',
['Cambio de disciplina o federación.','Competición estatal/internacional.','Licencia de menor.','Duplicidad de licencias o dudas de cobertura de seguro.','Participación de extranjero o deportista de otra federación territorial.'],
['ley_deporte','csd_licencias','rd_seguro','gencat_seguro'])

add(5,'Seguros y coberturas','Separar seguro deportivo, accidentes y responsabilidad del organizador','España - marco general; Cataluña como capa operativa',
'Los seguros deben analizarse por función. La cobertura ligada a una licencia deportiva no sustituye automáticamente la responsabilidad civil del organizador, ni toda póliza privada cubre cualquier competición, público o actividad de contacto.',
[
'El Real Decreto 849/1993 fija prestaciones mínimas del seguro obligatorio para deportistas federados que participan en competiciones oficiales de ámbito estatal en los términos de la norma.',
'En Cataluña, la normativa deportiva publicada por la Generalitat exige que determinadas licencias incorporen coberturas de responsabilidad civil, indemnización por pérdidas anatómicas/funcionales o fallecimiento y asistencia sanitaria, y advierte de responsabilidad subsidiaria del organizador en ciertos supuestos.',
'La normativa de espectáculos públicos puede exigir seguro de responsabilidad civil del titular/organizador según la actividad y el territorio.',
'Las cuantías concretas no deben copiarse de otra comunidad ni de otro tipo de recinto: hay que comprobar la norma territorial vigente y la póliza.'
],
['Inventariar actividades reales del club/evento.','Identificar qué participantes están cubiertos por licencia y en qué ámbito.','Solicitar certificado/póliza y revisar exclusiones.','Comprobar RC del organizador y del recinto.','Verificar si hay cobertura para público, voluntariado, personal y daños al recinto.','Revisar deporte de contacto, competición, exhibición y entrenamiento: pueden tratarse de forma distinta.','Documentar procedimiento de accidente y centros de asistencia.'],
['Seguro/licencia participante','RC organizador','RC recinto si procede','Accidentes/ asistencia','Exclusiones','Capitales y límites revisados','Procedimiento de siniestro','Teléfono/centro de asistencia','Vigencia día del evento'],
'Una licencia puede cubrir la asistencia sanitaria deportiva del participante, pero eso no significa automáticamente que cubra una caída de un espectador por una deficiencia del recinto. Son riesgos distintos.',
['Evento con público o alquiler de recinto.','Póliza excluye deportes de combate o competición.','Participantes no federados.','Actividad en otra comunidad/país.','Dudas sobre responsabilidad entre recinto, club y promotor.'],
['rd_seguro','gencat_seguro','gencat_eventos'])

add(6,'Menores en actividad y competición deportiva','Protección, consentimiento, datos, imagen y entorno seguro','España - obligaciones estatales; revisar protocolos autonómicos y federativos',
'Con menores no basta una autorización genérica firmada por la familia. Las entidades que trabajan habitualmente con menores tienen obligaciones específicas de prevención y respuesta frente a la violencia y deben separar correctamente consentimiento deportivo, tratamiento de datos e imagen.',
[
'La Ley Orgánica 8/2021 obliga a las entidades que realizan habitualmente actividades deportivas o de ocio con menores a aplicar protocolos, monitorizar su cumplimiento y designar un Delegado o Delegada de protección, entre otras medidas.',
'La Ley 39/2022 refuerza la protección de la práctica deportiva de menores y remite expresamente a las obligaciones de la Ley Orgánica 8/2021.',
'La Ley Orgánica 3/2018 fija en 14 años la edad general a partir de la cual un menor puede prestar consentimiento para tratamiento de datos cuando esa sea la base jurídica, con las excepciones legales correspondientes.',
'La difusión de imágenes de menores exige especial cautela; la autorización de participación deportiva no debe convertirse automáticamente en autorización de publicación en redes.'
],
['Identificar si la entidad trabaja habitualmente con menores.','Aplicar protocolo de protección y designar Delegado/a cuando corresponda.','Separar autorización deportiva, datos e imagen.','Limitar acceso a información sensible.','Definir canales de comunicación con familias y menores.','Formar a personal y técnicos en protección.','Definir respuesta ante incidentes, lesiones y revelaciones de violencia.','Revisar reglas federativas de edad, categorías, contacto y protecciones.'],
['Delegado/a de protección','Protocolo vigente','Canal de comunicación','Autorización de participación','Consentimientos de datos/imágenes separados cuando proceda','Contacto de responsables legales','Información médica mínima necesaria y protegida','Reglas de categoría/edad verificadas'],
'Una familia autoriza que su hijo participe en un interclub. Eso no permite asumir sin más que el club puede publicar su fotografía identificada en una campaña comercial; son finalidades distintas.',
['Evento con menores y público/streaming.','Viajes o pernoctaciones.','Combates de contacto con reglas de edad específicas.','Tratamiento de datos de salud.','Dudas sobre autorización de imagen o protección frente a violencia.'],
['lopiv','ley_deporte','lopdgdd','csd_menores'])

add(7,'Instalaciones, recintos y autorizaciones','Comprobar que el lugar está habilitado para la actividad real','España - régimen territorial/municipal; Cataluña como primera capa',
'Que un local tenga licencia para una actividad no significa que automáticamente pueda albergar cualquier evento deportivo, público o aforo. Debe comprobarse el uso autorizado, la actividad extraordinaria, el aforo y las condiciones de seguridad.',
[
'En Cataluña, Interior distingue los espectáculos y actividades extraordinarios que se celebran en establecimientos con licencia para una actividad diferente o en otros espacios abiertos al público.',
'El régimen de autorización/licencia depende del municipio, del tipo de espacio y del supuesto concreto; la Generalitat publica criterios generales y remite a ordenanzas municipales.',
'Los regímenes de seguridad aplicables a determinados espectáculos deportivos pueden añadir control de accesos, revisión del recinto, aforo y otros dispositivos.',
'No debe copiarse el aforo “habitual” de una sala a un montaje diferente sin validación técnica/administrativa.'
],
['Solicitar documentación del recinto.','Verificar actividad autorizada y aforo.','Confirmar si el montaje cambia salidas, gradas, ring, iluminación o circulación.','Revisar evacuación, incendios, accesibilidad y emergencias.','Determinar si necesita licencia/autorización/comunicación extraordinaria.','Coordinar seguridad, control de acceso y asistencia sanitaria según el evento.','Documentar revisión previa del montaje y apertura.'],
['Contrato/cesión recinto','Actividad autorizada','Aforo','Planos/montaje','Evacuación','Incendios','Accesibilidad','Seguridad','Plan sanitario','Autorización/licencia/comunicación si procede'],
'Un gimnasio autorizado para entrenamiento diario quiere instalar gradas temporales y vender 400 entradas. El uso, aforo y montaje cambian; no debe asumirse que la licencia ordinaria del gimnasio cubre el evento.',
['Gradas o estructuras temporales.','Aforo elevado.','Espacio abierto.','Cambio de actividad respecto a la licencia del recinto.','Evento en municipio con ordenanza específica.'],
['gencat_eventos','rd203','violencia'])

add(8,'Protección de datos, imagen y comunicaciones','Qué datos necesita realmente un club o evento y cómo tratarlos','España/UE - aplicación general; revisar bases jurídicas por proceso',
'Clubes, federaciones y organizadores manejan identidad, contacto, licencias, imágenes y, en ocasiones, información médica. No todos esos datos deben tratarse igual ni conservarse indefinidamente.',
[
'La LOPDGDD desarrolla el marco español de protección de datos y fija reglas específicas para consentimiento de menores y protección de su información en internet.',
'La publicación de imágenes y la gestión de datos de salud requieren especial cautela. El hecho de que un dato sea útil para organizar un evento no habilita automáticamente su uso comercial o público.',
'En sistemas de entradas nominativas o control de identidad sujetos a normativa específica, debe informarse del tratamiento de datos y limitarse a la finalidad aplicable.',
'La minimización es esencial: KOMBAX debe almacenar únicamente los datos necesarios para cada proceso y separar permisos internos de visibilidad pública.'
],
['Inventariar tratamientos: socios, deportistas, tutores, compradores, asistentes y personal.','Definir finalidad y base jurídica de cada tratamiento.','Separar datos operativos de datos públicos.','Aplicar permisos por rol e identidad activa.','Definir conservación y borrado.','Gestionar ejercicio de derechos.','Separar consentimiento de imagen/marketing cuando proceda.','Proteger especialmente salud, menores y documentos de identidad.'],
['Registro de tratamientos','Información de privacidad','Permisos internos','Consentimientos separados cuando apliquen','Política de conservación','Procedimiento de derechos','Control de exportación/descarga','Protección de datos sensibles'],
'Para crear una categoría de peso puede ser necesario registrar un peso deportivo. Publicar el historial completo de pesos en el perfil público es una finalidad distinta y no debería hacerse por defecto.',
['Se quiere publicar información médica, de menores o documentos.','Se comparten datos entre varios clubes/federaciones.','Se implanta reconocimiento, videovigilancia o control nominativo de entradas.','Se reciben solicitudes de acceso/borrado complejas.'],
['lopdgdd','lopiv','rd203'])

add(9,'Ticketing, venta de entradas y control de acceso','Vender una entrada implica contrato, información y operativa de acceso','España - consumo general; requisitos adicionales según evento/recinto',
'El ticketing combina consumo, pagos, seguridad, protección de datos y operativa del evento. KOMBAX puede automatizar el proceso, pero el organizador sigue siendo responsable de publicar condiciones correctas y gestionar cancelaciones e incidencias.',
[
'La normativa de consumo exige información precontractual clara, incluida identidad del empresario y precio final con impuestos y gastos aplicables.',
'En contratación electrónica con obligación de pago, la interfaz debe dejar claro que el pedido implica pago.',
'La Agència Catalana del Consum recuerda que, con carácter general, las entradas para espectáculos/servicios en fecha concreta no funcionan como una compra ordinaria con devolución libre; las condiciones y supuestos de cancelación deben informarse correctamente.',
'Para determinados espectáculos deportivos sujetos a la Ley 19/2007 y RD 203/2010 pueden existir requisitos adicionales sobre formato, control informatizado, aforo, venta y acceso.'
],
['Identificar organizador/vendedor contractual.','Mostrar precio final antes de pagar.','Publicar fecha, recinto, localidad/categoría y condiciones.','Definir política de cancelación, aplazamiento y reembolso.','Generar identificador/QR único y evitar duplicidades.','Controlar aforo y estados de check-in.','Informar del tratamiento de datos si la entrada es nominativa.','Mantener trazabilidad de reembolsos y anulaciones.'],
['Organizador identificado','Precio final','Condiciones visibles','Aforo','QR único','Política de reembolso','Canal de reclamación','Privacidad','Registro de check-in','Plan de contingencia offline'],
'“No se admiten devoluciones” no debería usarse como cláusula automática para cualquier situación. La cancelación o modificación del evento, lo prometido en la oferta y la normativa aplicable pueden generar obligaciones distintas.',
['Evento sometido a régimen especial de seguridad.','Entradas nominativas.','Cambio sustancial de fecha/recinto/cartel.','Reventa o intermediación.','Venta internacional.'],
['consumidores','gencat_consum','gencat_distancia','rd203','violencia'])

add(10,'Federaciones y relaciones federativas','Entender qué controla la federación y qué sigue siendo responsabilidad del club/organizador','España - marco estatal y autonómico/federativo',
'Las federaciones deportivas cumplen funciones de organización y regulación de su modalidad, especialmente en competición oficial. No todas las actividades privadas están automáticamente bajo el mismo régimen federativo, y no todas las entidades que se autodenominan “federación” tienen el mismo reconocimiento jurídico.',
[
'La Ley 39/2022 regula las federaciones deportivas españolas, licencias y competiciones oficiales en el ámbito estatal.',
'El CSD publica la relación y normativa de federaciones españolas y modalidades reconocidas.',
'Las federaciones autonómicas se rigen además por la normativa territorial y sus relaciones de integración con las federaciones españolas.',
'En Cataluña, las federaciones deportivas catalanas y entidades deportivas se inscriben en el REE conforme a la normativa autonómica.'
],
['Identificar si la organización/federación está reconocida oficialmente.','Comprobar modalidad y disciplina.','Leer reglamentos de competición, licencias, arbitraje y disciplina aplicables.','Separar evento privado de competición oficial.','Confirmar reconocimiento de resultados y récords antes de publicarlos como oficiales.','Registrar comunicaciones y autorizaciones federativas del evento.'],
['Federación competente','Modalidad','Reglamento vigente','Licencias','Árbitros/jueces','Autorización evento si procede','Reconocimiento de resultados','Seguro federativo','Canal de incidencias'],
'Que un promotor use reglas “tipo federación” no convierte sus resultados en resultados federativos oficiales. El reconocimiento depende de la organización competente y de su normativa.',
['Dudas entre dos federaciones u organizaciones.','Evento con varias disciplinas.','Resultados que se quieren incorporar a ranking oficial.','Conflicto entre licencia autonómica y estatal.'],
['ley_deporte','csd_ley','csd_licencias','gencat_ree'])

add(11,'Deportistas extranjeros y participación internacional','Entrada, trabajo, licencia y participación deportiva son controles distintos','España - extranjería estatal + normativa deportiva/federativa',
'Invitar a un deportista extranjero a competir en España exige separar al menos cuatro preguntas: puede entrar en España, necesita visado, realizará una actividad laboral/profesional, y cumple las reglas deportivas de la competición. Ninguna respuesta sustituye a las demás.',
[
'La normativa de extranjería vigente se desarrolla por el Real Decreto 1155/2024 y los procedimientos del Ministerio de Inclusión; el régimen depende de nacionalidad, duración, finalidad y existencia o no de actividad laboral/profesional.',
'El Ministerio publica procedimientos distintos para residencia/trabajo y para supuestos exceptuados de autorización de trabajo; para estancias de hasta 90 días puede ser necesario el correspondiente visado según el supuesto y nacionalidad.',
'El Real Decreto 1006/1985 remite la contratación por razón de nacionalidad a la legislación vigente de extranjería y preserva las reglas deportivas específicas de participación en competiciones.',
'La licencia, autorización federativa o invitación deportiva no debe presentarse como sustituto automático de los requisitos migratorios o laborales.'
],
['Identificar nacionalidad y residencia del deportista.','Definir duración de estancia.','Definir si recibe bolsa, salario, premio o contraprestación contractual.','Consultar requisitos consulares/migratorios vigentes antes de viajar.','Verificar licencia y reglas federativas de elegibilidad.','Asegurar cobertura sanitaria/deportiva.','Conservar cartas de invitación y contratos coherentes con la realidad.'],
['Pasaporte/documento','Visado/entrada si aplica','Situación laboral si aplica','Invitación/contrato','Licencia deportiva','Seguro','Reglas de competición','Datos de viaje/contacto'],
'Un luchador tailandés viene cuatro días para un seminario remunerado y un combate. No basta con “traerlo como invitado”: hay que revisar su régimen de entrada, la naturaleza económica de la actividad y las reglas deportivas aplicables.',
['Nacional de tercer país con remuneración.','Estancia superior a 90 días.','Contrato profesional.','Evento internacional/oficial.','Dudas sobre fiscalidad de pagos a no residentes.'],
['extranjeria','inclusion_trabajo','inclusion_excepcion','deportistas_prof','ley_deporte'])

add(12,'Patrocinio, marcas y colaboraciones','Distinguir patrocinio publicitario, colaboración y donación','España - marco contractual/fiscal general',
'“Patrocinio” se usa coloquialmente para operaciones distintas. Antes de emitir factura, certificado o contraprestación publicitaria hay que clasificar correctamente la relación.',
[
'La Ley General de Publicidad define el contrato de patrocinio publicitario como ayuda económica a cambio de colaboración en la publicidad del patrocinador.',
'La Ley 49/2002 regula los convenios de colaboración empresarial en actividades de interés general para entidades que cumplen los requisitos legales específicos; no cualquier club puede aplicar automáticamente ese régimen.',
'Una donación, un patrocinio publicitario, una aportación en especie y un convenio de colaboración pueden tener tratamiento jurídico/fiscal distinto.',
'Los derechos de imagen de deportistas y el uso de marcas/logotipos deben estar autorizados en el alcance acordado.'
],
['Definir qué aporta cada parte.','Definir qué recibe el patrocinador: logo, menciones, stands, contenido, entradas, naming, etc.','Identificar duración y territorios.','Regular uso de marcas e imagen.','Definir facturación/impuestos con asesoría fiscal cuando proceda.','Definir cancelación del evento y devolución/compensación.','Evitar prometer beneficios fiscales sin comprobar requisitos.'],
['Partes identificadas','Objeto','Contraprestaciones','Valor/importe','IVA/fiscalidad revisada','Uso de marca','Imagen','Duración','Cancelación','Entregables','Métricas si se prometen'],
'Una marca entrega 5.000 € a cambio de que su logo aparezca en cartel, ring y retransmisión. Eso encaja en una lógica publicitaria distinta de una aportación sin contraprestación.',
['Entidad quiere emitir certificado de donación.','Patrocinio con deportistas individuales.','Pago en especie importante.','Naming rights o exclusividad de categoría.','Operación transfronteriza.'],
['patrocinio','mecenazgo','aeat_actividad'])

add(13,'Organización de combates y participantes','Del matchmaking a la documentación verificable','Marco deportivo general; reglas concretas dependen de disciplina y organizador competente',
'La organización de combates exige controlar elegibilidad, categorías, licencias, reglas, pesajes, emparejamientos, protecciones, personal técnico y resultados. KOMBAX puede organizar información, pero no debe inventar reglas de una disciplina ni sustituir al órgano competente.',
[
'Las competiciones oficiales se rigen por la federación y reglamentos aplicables. La Ley 39/2022 sitúa licencias y organización oficial en ese marco.',
'La cobertura deportiva y de seguro debe verificarse antes de permitir participación.',
'Con menores, las reglas deportivas deben ser compatibles con su desarrollo y con las obligaciones reforzadas de protección.',
'Los resultados deben distinguir claramente entre oficial, homologado, exhibición, interclub o registro interno para evitar presentar como oficial lo que no lo es.'
],
['Definir modalidad y reglamento.','Verificar licencia/elegibilidad.','Registrar peso/categoría con privacidad adecuada.','Comprobar experiencia y restricciones de emparejamiento según reglas aplicables.','Asignar árbitros/jueces/personal técnico competente.','Definir equipamiento y protecciones.','Registrar pesaje, incidencias y resultado.','Marcar nivel de oficialidad del resultado.'],
['Participante','Club','Licencia','Categoría','Peso','Experiencia','Reglamento','Árbitro/jueces','Protecciones','Seguro','Resultado/estado','Incidencias'],
'Un resultado de sparring controlado puede ser útil como historial interno, pero no debe sumarse al récord oficial de un peleador si la organización competente no lo reconoce.',
['Dudas de categoría o experiencia.','Menores.','Diferencia grande de récord/peso.','Evento multideporte.','Se quiere alimentar ranking público u oficial.'],
['ley_deporte','csd_licencias','gencat_seguro','lopiv'])

add(14,'Documentación y checklist del organizador','Un expediente único para demostrar que el evento se preparó correctamente','España - checklist transversal adaptable al territorio',
'La mejor defensa operativa frente a errores es mantener un expediente del evento con versiones, responsables y evidencias. El checklist debe adaptarse al tipo de evento y no convertirse en una certificación automática de legalidad.',
[
'Las obligaciones proceden de varias capas: deportiva/federativa, recinto y espectáculos, seguros, consumo, privacidad, menores, extranjería, contratación y fiscalidad.',
'Guardar “un PDF” no es suficiente si no se sabe quién lo aprobó, para qué fecha, qué versión estaba vigente o a qué entidad corresponde.',
'KOMBAX debe favorecer trazabilidad: quién subió, quién verificó, vigencia y contexto de cada documento.'
],
['Crear ficha maestra del evento.','Asignar responsables por permisos, deporte, seguridad, ticketing y participantes.','Crear carpeta/versionado de permisos y pólizas.','Cerrar lista de participantes y personal.','Verificar recinto y montaje.','Cerrar ticketing/aforo.','Realizar reunión de apertura y checklist del día.','Registrar incidencias y decisiones.','Preparar cierre económico, reembolsos y archivo.'],
['Identidad organizador','Recinto','Permisos/comunicaciones','Seguros','Reglamento','Participantes/licencias','Menores','Extranjeros','Personal','Plan sanitario','Seguridad/acceso','Ticketing','Privacidad','Contratos/patrocinios','Cierre económico'],
'Una autorización municipal válida para una fecha concreta no debe reutilizarse como si cubriera automáticamente la siguiente edición del evento.',
['Evento complejo o multientidad.','Documentación con fechas/entidades contradictorias.','No está claro quién asume responsabilidad principal.','Faltan autorizaciones pocos días antes del evento.'],
['gencat_eventos','ley_deporte','consumidores','lopdgdd','lopiv','rd_seguro'])

add(15,'Obligaciones posteriores al evento','Cerrar pagos, incidencias, datos, resultados y documentación','España - cierre operativo, contractual, fiscal y documental',
'El evento no termina con el último combate. Después quedan pagos, reembolsos, reclamaciones, siniestros, resultados, documentación de participantes, datos personales y obligaciones contables/fiscales.',
[
'La normativa de consumo exige disponer de canales para reclamaciones y cumplir lo ofrecido contractualmente; las incidencias de cancelación o modificación deben documentarse.',
'Las obligaciones fiscales dependen de quién organiza, cómo se cobran entradas/servicios y qué pagos se realizan. La Agencia Tributaria recuerda que una actividad económica genera obligaciones antes, durante y después de la actividad.',
'Los datos personales no deben conservarse indefinidamente por comodidad. Hay que aplicar los plazos definidos por cada finalidad y por obligaciones legales.',
'Los resultados deportivos deben publicarse con su nivel de oficialidad real y corregirse si existe resolución posterior del órgano competente.'
],
['Cerrar conciliación de entradas, pagos y reembolsos.','Emitir/archivar documentación contable correspondiente.','Gestionar reclamaciones y chargebacks.','Comunicar siniestros a aseguradoras dentro de plazo aplicable.','Cerrar resultados y actas deportivas.','Registrar incidencias y acciones correctivas.','Revisar qué datos/documentos deben conservarse y cuáles deben eliminarse.','Cerrar contratos con proveedores/patrocinadores.','Generar informe post-evento.'],
['Ventas conciliadas','Reembolsos','Facturas/documentos','Siniestros','Reclamaciones','Resultados','Incidencias','Datos archivados/eliminados','Contratos cerrados','Informe final'],
'Si un evento se aplaza, la operativa posterior no se limita a cambiar una fecha en redes: puede afectar entradas, consumidores, recinto, permisos, seguros, contratos y participantes.',
['Cancelación o aplazamiento.','Accidente grave o reclamación.','Descuadre económico.','Chargebacks o fraude.','Conflicto sobre resultado deportivo.','Documentación fiscal o laboral compleja.'],
['consumidores','aeat_actividad','aeat_is','lopdgdd'])

# Verificación documental adicional 21/09/2026.
# Se añaden únicamente afirmaciones contrastadas con fuentes oficiales actuales.
for g in G:
    if g['n']==1:
        g['legal'].append('En Cataluña, la información oficial del REE indica que para constituir un club deportivo se necesitan como mínimo tres personas físicas con capacidad de actuar; esta regla es territorial y no debe extrapolarse automáticamente a otras comunidades autónomas.')
        if 'aeat_partial_current' not in g['sources']: g['sources'].append('aeat_partial_current')
    if g['n']==2:
        g['legal'].append('En Cataluña, Interior publica para actividades extraordinarias requisitos supletorios que pueden abarcar responsable identificado, movilidad, vigilancia/control de acceso, autoprotección, higiene y seguridad, asistencia sanitaria, aforo, impacto acústico, responsabilidad civil y disponibilidad del espacio. La aplicabilidad concreta depende del supuesto y de la ordenanza municipal.')
        if 'gencat_pau' not in g['sources']: g['sources'].append('gencat_pau')
    if g['n']==6:
        g['legal'].append('Cataluña dispone de un Protocol marc de protecció d’infants i adolescents davant les violències en l’àmbit esportiu aprobado por GOV/252/2023; la segunda edición fue revisada en febrero de 2025. Debe comprobarse su aplicación junto con los protocolos de la entidad y de la organización deportiva competente.')
        for k in ['gencat_minor_protocol','aepd_images']:
            if k not in g['sources']: g['sources'].append(k)
    if g['n']==8:
        g['legal'].append('La AEPD recuerda que la protección de datos por defecto exige minimizar cantidad, extensión del tratamiento, conservación y accesibilidad desde el diseño. KOMBAX debe reflejar esta regla en formularios, visibilidad de perfiles y publicaciones.')
        for k in ['aepd_default','aepd_images']:
            if k not in g['sources']: g['sources'].append(k)
    if g['n']==10:
        g['legal'].append('La AEPD señala que las federaciones deportivas que tratan datos de menores de edad están obligadas a designar una persona Delegada de Protección de Datos y comunicar la designación a la autoridad de control correspondiente.')
        if 'aepd_dpd_fed' not in g['sources']: g['sources'].append('aepd_dpd_fed')
    if g['n']==11:
        if 'inclusion_sheets' not in g['sources']: g['sources'].append('inclusion_sheets')
    if g['n'] in (12,15):
        if 'aeat_partial_current' not in g['sources']: g['sources'].append('aeat_partial_current')

# research matrix markdown
with open(SRC/'SOURCES_MATRIX.md','w',encoding='utf-8') as f:
    f.write('# KOMBAX Guías - Matriz de fuentes oficiales\n\n')
    f.write(f'**Revisión documental:** {REVIEW}\n\n')
    f.write('Prioridad: fuentes oficiales. Esta matriz no convierte una fuente general en requisito aplicable a cualquier caso; cada guía indica sus límites territoriales y materiales.\n\n')
    for k,(t,o,u) in sources.items():
        f.write(f'- **{k}** - {t}. {o}. {u}\n')

# guide markdown
for g in G:
    slug=f"{g['n']:02d}_"+re.sub(r'[^a-z0-9]+','_',g['title'].lower().translate(str.maketrans('áéíóúñü','aeiounu'))).strip('_')
    p=SRC/f'{slug}.md'
    with open(p,'w',encoding='utf-8') as f:
        f.write(f"# KOMBAX Guías {g['n']:02d} - {g['title']}\n\n")
        f.write(f"**{g['subtitle']}**\n\n**Ámbito:** {g['scope']}  \n**Revisión:** {REVIEW}\n\n")
        f.write('> Material informativo y operativo. No sustituye asesoramiento jurídico, fiscal, laboral, federativo o técnico específico. Verifica siempre la norma, trámite y reglamento vigentes para tu caso.\n\n')
        f.write('## Qué resuelve esta guía\n\n'+g['summary']+'\n\n')
        f.write('## Marco verificado\n\n')
        for x in g['legal']: f.write(f'- {x}\n')
        f.write('\n## Ruta práctica\n\n')
        for i,x in enumerate(g['steps'],1): f.write(f'{i}. {x}\n')
        f.write('\n## Checklist\n\n')
        for x in g['checklist']: f.write(f'- [ ] {x}\n')
        f.write('\n## Ejemplo práctico\n\n'+g['example']+'\n\n')
        f.write('## Cuándo pasar a KOMBAX Consultoría\n\n')
        for x in g['consult']: f.write(f'- {x}\n')
        f.write('\n**Qué puede revisar una consultoría específica:** clasificación del caso, territorio y organismo competente, documentación concreta, contradicciones entre permisos/reglamentos, checklist personalizado y puntos que requieren validación profesional externa.\n\n')
        f.write('## Fuentes oficiales consultadas\n\n')
        for k in g['sources']:
            t,o,u=sources[k]; f.write(f'- {t} - {o}: {u}\n')
        f.write('\n## Límites de la guía\n\n')
        f.write('No se han fijado importes de seguros, tasas, licencias, honorarios, plazos municipales ni documentación federativa específica cuando no existe una regla única aplicable a todos los supuestos. Esos datos deben verificarse en el territorio, recinto, federación y modalidad concretos.\n')

# PDF styles
PAGE_W,PAGE_H=A4
C_BG=colors.HexColor('#090B10'); C_PANEL=colors.HexColor('#111722'); C_ACC=colors.HexColor('#F04452'); C_CYAN=colors.HexColor('#37D6E8'); C_TEXT=colors.HexColor('#E9EEF6'); C_MUTED=colors.HexColor('#AAB4C3'); C_WARN=colors.HexColor('#F4C76A')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='KTitle',fontName='DejaVu-Bold',fontSize=25,leading=29,textColor=C_TEXT,spaceAfter=10))
styles.add(ParagraphStyle(name='KSub',fontName='DejaVu',fontSize=11.5,leading=16,textColor=C_MUTED,spaceAfter=12))
styles.add(ParagraphStyle(name='KH1',fontName='DejaVu-Bold',fontSize=15,leading=19,textColor=C_ACC,spaceBefore=12,spaceAfter=7))
styles.add(ParagraphStyle(name='KBody',fontName='DejaVu',fontSize=9.3,leading=13.6,textColor=colors.HexColor('#1B2430'),spaceAfter=6))
styles.add(ParagraphStyle(name='KBold',fontName='DejaVu-Bold',fontSize=9.3,leading=13.6,textColor=colors.HexColor('#1B2430'),spaceAfter=5))
styles.add(ParagraphStyle(name='KSmall',fontName='DejaVu',fontSize=7.5,leading=10.2,textColor=colors.HexColor('#475569'),spaceAfter=3))
styles.add(ParagraphStyle(name='KCall',fontName='DejaVu-Bold',fontSize=9.8,leading=13.5,textColor=colors.HexColor('#61121A'),spaceAfter=4))
styles.add(ParagraphStyle(name='KTOC',fontName='DejaVu',fontSize=9.5,leading=13,textColor=colors.HexColor('#253047'),spaceAfter=3))

def footer(canvas,doc):
    canvas.saveState();
    canvas.setFillColor(colors.HexColor('#6B7280')); canvas.setFont('DejaVu',7)
    canvas.drawString(18*mm,10*mm,f'KOMBAX Guías · Revisión {REVIEW}')
    canvas.drawRightString(PAGE_W-18*mm,10*mm,f'{doc.page}')
    canvas.restoreState()

def cover_story(g):
    elems=[]
    # Approved KOMBAX Guías hero audited against existing Social/Showcase/Events visual family.
    if GUIDES_HERO.exists():
        img=Image(str(GUIDES_HERO),width=174*mm,height=97.9*mm)
        elems += [img,Spacer(1,4*mm)]
    data=[[Paragraph(f"KOMBAX GUÍAS · {g['n'] if isinstance(g['n'],str) else f'{g['n']:02d}'}",ParagraphStyle('tag',fontName='DejaVu-Bold',fontSize=9,textColor=C_CYAN)), ''],
          [Paragraph(g['title'],styles['KTitle']), ''],
          [Paragraph(g['subtitle'],styles['KSub']), ''],
          [Paragraph(f"Ámbito: {g['scope']}",ParagraphStyle('scope',fontName='DejaVu',fontSize=9.5,textColor=C_TEXT)), ''],
          [Paragraph(f"Última revisión: {REVIEW}",ParagraphStyle('date',fontName='DejaVu',fontSize=8,textColor=C_MUTED)), '']]
    t=Table(data,colWidths=[160*mm,0],rowHeights=[8*mm,26*mm,16*mm,12*mm,8*mm])
    t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),C_BG),('BOX',(0,0),(-1,-1),0,C_BG),('LEFTPADDING',(0,0),(-1,-1),9*mm),('RIGHTPADDING',(0,0),(-1,-1),8*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),2*mm)]))
    elems += [t,Spacer(1,5*mm)]
    warning=Table([[Paragraph('<b>Uso:</b> información general y checklist operativo. No sustituye asesoramiento específico. Cuando un requisito dependa del municipio, comunidad autónoma, federación, recinto o modalidad, la guía lo indica en lugar de inventar una respuesta.',styles['KBody'])]],colWidths=[174*mm])
    warning.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFF8E7')),('BOX',(0,0),(-1,-1),0.6,C_WARN),('LEFTPADDING',(0,0),(-1,-1),5*mm),('RIGHTPADDING',(0,0),(-1,-1),5*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    elems += [warning,PageBreak()]
    return elems

def bullets(items, numbered=False, checks=False):
    out=[]
    for i,x in enumerate(items,1):
        prefix=f'{i}. ' if numbered else ('☐ ' if checks else '• ')
        out.append(Paragraph(prefix+x,styles['KBody']))
    return out

def build_pdf(g,path):
    doc=SimpleDocTemplate(str(path),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=17*mm,bottomMargin=17*mm,author='KOMBAX Spain',title=f"KOMBAX Guías {g['n']:02d} - {g['title']}")
    story=cover_story(g)
    story += [Paragraph('Qué resuelve esta guía',styles['KH1']),Paragraph(g['summary'],styles['KBody'])]
    story += [Paragraph('Marco verificado',styles['KH1'])]+bullets(g['legal'])
    story += [Paragraph('Ruta práctica',styles['KH1'])]+bullets(g['steps'],numbered=True)
    story += [Paragraph('Checklist operativo',styles['KH1'])]+bullets(g['checklist'],checks=True)
    story += [Paragraph('Ejemplo práctico',styles['KH1']),Paragraph(g['example'],styles['KBody'])]
    call=Table([[Paragraph('CUÁNDO PASAR A KOMBAX CONSULTORÍA',styles['KCall'])],[Paragraph('Si tu caso entra en alguno de estos supuestos, conviene revisar la situación concreta antes de actuar.',styles['KBody'])]],colWidths=[174*mm])
    call.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFF0F2')),('BOX',(0,0),(-1,-1),0.7,C_ACC),('LEFTPADDING',(0,0),(-1,-1),5*mm),('RIGHTPADDING',(0,0),(-1,-1),5*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    story += [Spacer(1,4*mm),call]+bullets(g['consult'])
    story += [Paragraph('Qué puede aportar una consulta específica',styles['KH1']),Paragraph('Clasificación del caso, identificación del organismo competente, revisión de documentación, checklist personalizado, detección de contradicciones entre normativa/recinto/federación y señalamiento de los puntos que deben ser validados por un profesional jurídico, fiscal, laboral, técnico o federativo cuando corresponda.',styles['KBody'])]
    story += [Paragraph('Fuentes oficiales consultadas',styles['KH1'])]
    for k in g['sources']:
        t,o,u=sources[k]
        story.append(Paragraph(f'<b>{t}</b> · {o}<br/><font size="7">{u}</font>',styles['KSmall']))
    story += [Paragraph('Límites y actualización',styles['KH1']),Paragraph('No se han fijado importes de seguros, tasas, licencias, honorarios, plazos municipales ni requisitos federativos específicos cuando no existe una regla única para todos los supuestos. Antes de usar esta guía como base de una actuación real, comprueba que la fecha de revisión sigue vigente y que no se ha producido una modificación normativa o reglamentaria.',styles['KBody'])]
    doc.build(story,onFirstPage=footer,onLaterPages=footer)

for g in G:
    slug=f"KOMBAX_GUIA_{g['n']:02d}_"+re.sub(r'[^A-Z0-9]+','_',g['title'].upper().translate(str.maketrans('ÁÉÍÓÚÑÜ','AEIOUNU'))).strip('_')+'.pdf'
    build_pdf(g,OUT/slug)

# master PDF
master=OUT/'KOMBAX_GUIAS_ESPANA_CATALUNA_COLECCION_INICIAL_2026.pdf'
doc=SimpleDocTemplate(str(master),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=17*mm,bottomMargin=17*mm,author='KOMBAX Spain',title='KOMBAX Guías - Colección inicial España / Cataluña 2026')
story=[]
cover=dict(n='COLECCIÓN',title='KOMBAX Guías',subtitle='Normativa · recursos · checklists · acceso a consultoría',scope='España + primera capa autonómica desarrollada para Cataluña')
story += cover_story(cover)
story += [Paragraph('Cómo usar esta colección',styles['KH1']),Paragraph('Esta edición reúne 15 guías operativas. No intenta convertir la normativa deportiva española en una lista universal. Cada capítulo distingue el marco común de los puntos que dependen de comunidad autónoma, municipio, modalidad, federación, recinto o condición del participante.',styles['KBody'])]
story += [Paragraph('Índice',styles['KH1'])]
for g in G: story.append(Paragraph(f"{g['n']:02d}. {g['title']} — {g['subtitle']}",styles['KTOC']))
story.append(PageBreak())
for idx,g in enumerate(G):
    story += [Paragraph(f"KOMBAX GUÍAS · {g['n'] if isinstance(g['n'],str) else f'{g['n']:02d}'}",ParagraphStyle('tag2',fontName='DejaVu-Bold',fontSize=8.5,textColor=C_CYAN,spaceAfter=4)),Paragraph(g['title'],ParagraphStyle('mtitle',fontName='DejaVu-Bold',fontSize=21,leading=25,textColor=colors.HexColor('#111827'),spaceAfter=5)),Paragraph(g['subtitle'],ParagraphStyle('msub',fontName='DejaVu',fontSize=10.5,leading=14,textColor=colors.HexColor('#64748B'),spaceAfter=8)),Paragraph(f"Ámbito: {g['scope']} · Revisión: {REVIEW}",styles['KSmall'])]
    story += [Paragraph('Qué resuelve esta guía',styles['KH1']),Paragraph(g['summary'],styles['KBody'])]
    story += [Paragraph('Marco verificado',styles['KH1'])]+bullets(g['legal'])
    story += [Paragraph('Ruta práctica',styles['KH1'])]+bullets(g['steps'],numbered=True)
    story += [Paragraph('Checklist',styles['KH1'])]+bullets(g['checklist'],checks=True)
    story += [Paragraph('Ejemplo',styles['KH1']),Paragraph(g['example'],styles['KBody'])]
    story += [Paragraph('Cuándo solicitar KOMBAX Consultoría',styles['KH1'])]+bullets(g['consult'])
    story += [Paragraph('Fuentes',styles['KH1'])]
    for k in g['sources']:
        t,o,u=sources[k]; story.append(Paragraph(f'{t} · {o}<br/><font size="7">{u}</font>',styles['KSmall']))
    story += [Paragraph('Límite',styles['KH1']),Paragraph('Verifica siempre norma y procedimiento vigentes para el caso concreto. Esta guía evita deliberadamente inventar importes, plazos o requisitos cuando dependen de una administración, federación, modalidad o recinto específico.',styles['KBody'])]
    if idx<len(G)-1: story.append(PageBreak())
doc.build(story,onFirstPage=footer,onLaterPages=footer)

# index JSON for future ingestion
index=[]
for g in G:
    index.append({k:g[k] for k in ['n','title','subtitle','scope','summary','legal','steps','checklist','example','consult','sources']})
with open(SRC/'guides_index.json','w',encoding='utf-8') as f: json.dump({'review_date':REVIEW,'regional_layer':'Cataluña','guides':index,'sources':sources},f,ensure_ascii=False,indent=2)

print('Generated',len(G),'individual guides + master')
print(master)
