<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns:rng="http://relaxng.org/ns/structure/1.0"
  xmlns:rnga="http://relaxng.org/ns/compatibility/annotations/1.0"
  xmlns:rng2ditadtd="http://dita.org/rng2ditadtd"
  xmlns:relpath="http://dita2indesign/functions/relpath"
  xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0"
  xmlns:str="http://local/stringfunctions"
  xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
  xmlns:dita="http://dita.oasis-open.org/architecture/2005/"
  xmlns:rngfunc="http://dita.oasis-open.org/dita/rngfunctions"
  xmlns:local="http://local-functions"
  exclude-result-prefixes="xs xd rng rnga relpath a str ditaarch dita rngfunc local rng2ditadtd"
  version="2.0">

  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p>RNG to DITA DTD Converter</xd:p>
      <xd:p><xd:b>Created on:</xd:b> Feb 16, 2013</xd:p>
      <xd:p><xd:b>Authors:</xd:b> ekimber, pleblanc</xd:p>
      <xd:p>This transform takes as input RNG-format DITA document type
      shells and produces from them the DTD shell that
        that reflects the RNG definitions and conforms to the DITA 1.3
        DTD coding requirements.
      </xd:p>
    </xd:desc>
  </xd:doc>

  <!-- ==============================
       .dtd file generation mode
       ============================== -->

  <xsl:template match="rng:grammar" mode="dtdFile">
    <xsl:param name="dtdFilename" tunnel="yes" as="xs:string" />
    <xsl:param name="dtdDir" tunnel="yes" as="xs:string" />
    <xsl:param name="modulesToProcess" tunnel="yes" as="document-node()*" />
    
    <xsl:variable name="rootElement" 
      select="substring-before(/*/rng:start/rng:ref/@name,'.element')" 
      as="xs:string" />
    
    <xsl:message> + [INFO] === Generating DTD shell <xsl:value-of select="$dtdFilename" />...</xsl:message>
    
    
    <xsl:variable name="shellType" select="rngfunc:getModuleType(.)" as="xs:string"/>
    
    <xsl:if test="$shellType != 'topicshell' and $shellType != 'mapshell'">
      <xsl:message terminate="yes"> - [ERROR] mode dtdFile: Expected module type 'topicshell' or 'mapshell', got "<xsl:sequence select="$shellType"/>".</xsl:message>
    </xsl:if>
    
    <!-- ====================================
         Start generating the shell DTD file:
         ==================================== -->
    
    <xsl:text>&lt;?xml version="1.0" encoding="UTF-8"?>&#x0a;</xsl:text>

    <xsl:apply-templates select="dita:moduleDesc" mode="header-comment"/>

    <xsl:choose>
      <xsl:when test="$shellType='mapshell'">
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                MAP ENTITY DECLARATIONS                        -->
&lt;!-- ============================================================= -->
</xsl:text>
      </xsl:when>
      <xsl:when test="$shellType='topicshell'">
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--              TOPIC ENTITY DECLARATIONS                        -->
&lt;!-- ============================================================= -->
</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:choose>
      <!-- The base topic module is a special case in that it has no
           corresponding .ent file.
        -->
      <xsl:when test="count(*)=1 and rng:include">
        <!--  simple redirection, as in technicalContent\glossary.dtd -->
        <xsl:apply-templates mode="dtdRedirect" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates 
          select="$modulesToProcess[rngfunc:getModuleType(*) = 'topic']" 
          mode="entityDeclaration" >
          <xsl:with-param 
            name="entityType" 
            select="'ent'" 
            as="xs:string" 
            tunnel="yes"
          />
        </xsl:apply-templates>

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--             DOMAIN ENTITY DECLARATIONS                        -->
&lt;!-- ============================================================= -->
</xsl:text>
        
        <xsl:apply-templates 
          select="$modulesToProcess[rngfunc:getModuleType(*) = 'elementdomain']" 
          mode="entityDeclaration" 
        >
          <xsl:with-param 
            name="entityType" 
            select="'ent'" 
            as="xs:string" 
            tunnel="yes"
          />
        </xsl:apply-templates>

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--             DOMAIN ATTRIBUTES DECLARATIONS                    -->
&lt;!-- ============================================================= -->
</xsl:text>
        
        <xsl:apply-templates 
          select="$modulesToProcess[rngfunc:getModuleType(*) = 'attributedomain']" 
          mode="entityDeclaration" 
        >
          <xsl:with-param 
            name="entityType" 
            select="'ent'" 
            as="xs:string" 
            tunnel="yes"
          />
        </xsl:apply-templates>


<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    DOMAIN EXTENSIONS                          -->
&lt;!-- ============================================================= -->
&lt;!--                    One for each extended base element, with
                        the name of the domain(s) in which the
                        extension was declared                     -->
</xsl:text>
        <!-- Get the set of element domain modules then get the set of 
             domain extension patterns from all of them then process
             that set to generate one parameter entity for each unique
             element type being extended.
             
             Note: No space between declarations within this group.
          -->
        <xsl:message> + [INFO] Generating domain extension integration entities... </xsl:message>
        <xsl:variable name="domainModules" as="element()*"
          select="$modulesToProcess[rngfunc:isElementDomain(.)]/*" 
        />
        <xsl:message> + [INFO] Domain modules to integrate: <xsl:sequence select="for $mod in $domainModules return rngfunc:getModuleShortName($mod)"/></xsl:message>
        <xsl:variable name="domainExtensionPatterns" as="element()*"
          select="$domainModules//rng:define[starts-with(@name, rngfunc:getModuleShortName(root(.)/*))]"
        />
        
        <xsl:for-each-group select="$domainExtensionPatterns" 
          group-by="substring-after(@name, concat(rngfunc:getModuleShortName(root(.)/*), '-'))">
<!--          <xsl:message> + [DEBUG   current-grouping-key="<xsl:sequence select="current-grouping-key()"/>"</xsl:message>-->
            <xsl:variable name="firstPart" as="xs:string"
              select="concat('&#x0a;&lt;!ENTITY % ', current-grouping-key())"
            />
            <xsl:value-of select="$firstPart"/>
            <xsl:value-of 
              select="if (string-length($firstPart) lt 26) 
              then str:indent(25 - string-length($firstPart)) 
              else ' ' "/>
            <xsl:text>"</xsl:text>
            <xsl:value-of select="concat(current-grouping-key(), ' |', '&#x0a;', str:indent(25))"/>
            <xsl:variable name="sep" as="xs:string"
              select="concat(' |', '&#x0a;', str:indent(25))"
            />
            <xsl:value-of select="
              string-join(for $pattern in current-group() return concat('%', $pattern/@name, ';'), $sep)
              "/>
            <xsl:text>&#x0a;</xsl:text>
            <xsl:value-of select="str:indent(24)"/>
            <xsl:text>"></xsl:text>          
        </xsl:for-each-group>
        <xsl:text>&#x0a;</xsl:text>
        
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    DOMAIN ATTRIBUTE EXTENSIONS                -->
&lt;!-- ============================================================= -->

</xsl:text>
<!--
<!ENTITY % props-attribute-extensions  
  ""
>
<!ENTITY % base-attribute-extensions   
  ""
>       
-->          
        <xsl:variable name="domainModules" as="element()*"
          select="$modulesToProcess[rngfunc:isAttributeDomain(.)]/*" 
        />
        <!-- ====== @props extensions ============ -->
        <xsl:variable name="propsExtensionPatterns" as="element()*"
          select="$domainModules//rng:define[@name = 'props-attribute-extensions']"
        />
<xsl:text>&lt;!ENTITY % props-attribute-extensions&#x0a;</xsl:text>
<xsl:text>  "</xsl:text>
        <xsl:for-each-group select="$propsExtensionPatterns" group-by="@name">
            <!-- Here the referenced attribute group becomes the name of the entity 
                 we want to reference. There should be exactly one <rng:ref> element
                 within this <define>:
                 
  <define name="props-attribute-extensions" combine="interleave">
    <ref name="deliveryTargetAtt-d-attribute"/>
  </define>

              -->
            <xsl:variable name="entityName" as="xs:string"
              select="rng:ref/@name"
            />
          <xsl:value-of select="concat('%', $entityName, ';', 
            if (position() != last()) then concat('&#x0a;', str:indent(3)) else '')"/>
        </xsl:for-each-group>
<xsl:text>"&#x0a;&gt;&#x0a;</xsl:text>
        
        <!-- ====== @base extensions ============ -->
        <xsl:variable name="baseExtensionPatterns" as="element()*"
          select="$domainModules//rng:define[@name = 'base-attribute-extensions']"
        />
<xsl:text>&lt;!ENTITY % base-attribute-extensions&#x0a;</xsl:text>
<xsl:text>  "</xsl:text>
        <xsl:for-each-group select="$baseExtensionPatterns" group-by="@name">
            <!-- Here the referenced attribute group becomes the name of the entity 
                 we want to reference. There should be exactly one <rng:ref> element
                 within this <define>:
                 
  <define name="base-attribute-extensions" combine="interleave">
    <ref name="deliveryTargetAtt-d-attribute"/>
  </define>

              -->
            <xsl:variable name="entityName" as="xs:string"
              select="rng:ref/@name"
            />
          <xsl:value-of select="concat('%', $entityName, ';', 
            if (position() != last()) then concat('&#x0a;', str:indent(3)) else '')"/>
        </xsl:for-each-group>
<xsl:text>"&#x0a;&gt;&#x0a;</xsl:text>
        

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    TOPIC NESTING OVERRIDE                     -->
&lt;!-- ============================================================= -->
&#x0a;</xsl:text>
        
    <!-- The *-info-types pattern will always be defined in the topic module
         but may also be overridden in the reference to the module. Thus,
         for each reference to a topic module we have to see what the effective
         definition for the {topictype}-info-types pattern is and use it
         here.
      -->
        <xsl:variable name="topicModuleIncludes" as="element()*">
          <xsl:for-each select=".//rng:include">
            <xsl:variable name="module" select="document(@href,.)"/>
            <xsl:if test="rngfunc:getModuleType($module/*) = 'topic'">
              <xsl:sequence select="."/>
            </xsl:if>              
          </xsl:for-each>
        </xsl:variable>
        
        <xsl:for-each select="$topicModuleIncludes">
          <xsl:choose>
            <xsl:when test=".//rng:define">
              <xsl:apply-templates select=".//rng:define" mode="generate-parment-decl-from-define"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="module" select="document(./@href,.)" as="document-node()"/>
              <xsl:variable name="topicType" as="xs:string" select="rngfunc:getModuleShortName($module/*)"/>
              <!-- The topic module is always included and we don't want to 
                   reflect its -info-types pattern (because it's always just "topic").
                   
                   However, for shells that are configuring <topic>, we do want it.
                -->
              <xsl:if test="$topicType != 'topic' or (normalize-space(//rng:start/rng:ref/@name) = 'topic.element')">
                <xsl:apply-templates 
                  select="$module//rng:define[ends-with(@name, '-info-types')]"
                  mode="generate-parment-decl-from-define"
                />
              </xsl:if>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>

        <!-- Only the ditabase doctype has a locally-defined containment
             section.
          -->
        <xsl:if test="$rootElement = 'ditabase'">
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    LOCALLY DEFINED CONTAINMENT                -->
&lt;!-- ============================================================= -->
</xsl:text>
          <xsl:apply-templates select="rng:define/rng:element" mode="localDefinition" />
        </xsl:if>

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    DOMAINS ATTRIBUTE OVERRIDE                 -->
&lt;!-- ============================================================= -->
</xsl:text>
        <xsl:variable name="domainModules" as="element()*">
          <xsl:for-each select=".//rng:include">
            <xsl:variable name="module" select="document(@href,.)"/>
            <xsl:if test="
               rngfunc:isElementDomain($module) or 
               rngfunc:isAttributeDomain($module)  or 
               (rngfunc:isTypeModule($module) and 
                not(rngfunc:getModuleShortName($module/*) = 'topic'))">
              <xsl:sequence select="$module/*"/>
            </xsl:if>              
          </xsl:for-each>
        </xsl:variable>

        <xsl:text>&#x0a;&lt;!ENTITY included-domains&#x0a;</xsl:text>
        <xsl:value-of select="str:indent(26)"/>
        <xsl:text>"</xsl:text>
          <xsl:for-each select="$domainModules">
            <xsl:variable name="attRef" as="xs:string"
              select="concat('&amp;', normalize-space(rngfunc:getModuleShortName(.)), '-att', ';', '&#x0a;')"
            />
            <xsl:if test="position() > 1">
              <xsl:value-of select="str:indent(27)"/>
            </xsl:if>
            <xsl:value-of select="$attRef"/>
          </xsl:for-each>
        <xsl:text>  "&#x0a;>&#x0a;</xsl:text>

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    CONTENT CONSTRAINT INTEGRATION             -->
&lt;!-- ============================================================= -->
</xsl:text>
        <xsl:apply-templates 
          select="$modulesToProcess[rngfunc:getModuleType(*) = 'constraint']" 
          mode="attributeExtension" 
        >
          <xsl:with-param 
            name="entityType" 
            select="'mod'" 
            as="xs:string" 
            tunnel="yes"
          />
        </xsl:apply-templates>

    <xsl:choose>
      <xsl:when test="$shellType='mapshell'">
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                      MAP ELEMENT INTEGRATION                  -->
&lt;!-- ============================================================= -->
</xsl:text>
      </xsl:when>
      <xsl:when test="$shellType='topicshell'">
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    TOPIC ELEMENT INTEGRATION                  -->
&lt;!-- ============================================================= -->
</xsl:text>
      </xsl:when>
      <xsl:otherwise>
<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                       ELEMENT INTEGRATION                     -->
&lt;!-- ============================================================= -->
</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
          <xsl:apply-templates 
            select="$modulesToProcess[rngfunc:getModuleType(*) = 'topic' or 
                                      rngfunc:getModuleType(*) = 'map']"
            mode="entityDeclaration"
          >
            <xsl:with-param 
              name="entityType" 
              select="'type'" 
              as="xs:string" 
              tunnel="yes"
            />
          </xsl:apply-templates>
          

<xsl:text>
&lt;!-- ============================================================= -->
&lt;!--                    DOMAIN ELEMENT INTEGRATION                 -->
&lt;!-- ============================================================= -->
</xsl:text>
        <xsl:apply-templates 
          select="$modulesToProcess[rngfunc:getModuleType(*) = 'elementdomain']" 
          mode="entityDeclaration" 
        >
          <xsl:with-param 
            name="entityType" 
            select="'mod'" 
            as="xs:string" 
            tunnel="yes"
          />
        </xsl:apply-templates>


      </xsl:otherwise>
    </xsl:choose>
    
    <xsl:text>
&lt;!-- ================= End of </xsl:text>
    <xsl:value-of select="rngfunc:getModuleTitle(.)"/>
    <xsl:text> ================= --></xsl:text>
    
    <xsl:message> + [INFO] === DTD shell <xsl:value-of select="$dtdFilename" /> generated.</xsl:message>

  </xsl:template>

  <xsl:template match="rng:include" mode="dtdRedirect">
    
    <!-- FIXME: Should be able to put this through the generic entity
                reference code, but not 100% sure.
      -->
    <xsl:variable name="dtdRedirect" select="substring-before(@href,'.rng')" />
    <xsl:variable name="dtdDoc" select="document(@href)" as="document-node()" />
    <xsl:variable name="dtdPublicId" 
      select="rngfunc:getPublicId($dtdDoc/*, 'dtdMod')" />
    <xsl:text>&#x0a;&lt;!ENTITY % </xsl:text><xsl:value-of select="concat($dtdRedirect,'Dtd')" /> 
    <xsl:text>&#x0a;  PUBLIC "</xsl:text><xsl:value-of select="$dtdPublicId" /><xsl:text>" &#x0a;         "</xsl:text>
    <xsl:value-of select="concat($dtdRedirect,'.dtd')" />
    <xsl:text>"&#x0a;>&#x0a;%</xsl:text>
    <xsl:value-of select="concat($dtdRedirect,'Dtd')" /> 
    <xsl:text>;&#x0a;</xsl:text>
    
  </xsl:template>



  <xsl:template match="*" mode="entityDeclaration">
    <xsl:apply-templates mode="#current" select="node()" />
  </xsl:template>

  <xsl:template match="rng:grammar" mode="entityDeclaration">
    <xsl:param 
      name="entityType" 
      as="xs:string" 
      tunnel="yes"
    /><!-- One of "type, "ent", or "mod" 
      
           Note that "type" = "mod" for the purposes of
           constructing filenames because topic and map
           modules use an entity name of *-type.
    -->
    <xsl:param name="dtdDir" tunnel="yes" as="xs:string" />
    <xsl:param name="rngShellUrl" tunnel="yes" as="xs:string"/>
    
    <xsl:variable name="rngShellParent" as="xs:string"
      select="relpath:getParent($rngShellUrl)"
    />
    
    <xsl:variable name="filenameSuffix" as="xs:string"
      select="if ($entityType = 'type') then 'mod' else $entityType"
    />
    <xsl:variable name="entityNameSuffix" as="xs:string"
      select="if ($entityType = 'ent')
         then '-dec'
         else if ($entityType = 'type') then '-type' else '-def'"
    />
    
    <!-- Have to special case the base topic module as its .ent file is named "topicDefn.ent"
         rather than topic.ent.
      -->
    <xsl:variable name="entFilename" as="xs:string"
      select="rngfunc:getEntityFilename(., $filenameSuffix)"
    />
    <xsl:variable name="moduleUrl" as="xs:string"
      select="rngfunc:getGrammarUri(.)"
    />
    <xsl:variable name="relpathFromShell" as="xs:string"
      select="relpath:getParent(relpath:getRelativePath($rngShellParent, $moduleUrl))"
      />
    <xsl:variable name="shortName" as="xs:string"
      select="rngfunc:getModuleShortName(.)"
    />
    <xsl:variable name="pubidTagname" as="xs:string"
      select="concat('dtd', if ($entityType = 'ent') then 'Ent' else 'Mod')"
    />
    <xsl:variable name="publicId" 
      select="rngfunc:getPublicId(., $pubidTagname)" 
    />
    <xsl:variable name="entityName" as="xs:string"
      select="concat($shortName, $entityNameSuffix)"
    />
    <!-- FIXME: The replace is a short-term hack to avoid figuring out how to
                generalize the code for getting the result URI for a module
                so we can construct the relative output path properly.
                This hack will work for OASIS files but not necessarily 
                any other organization pattern.
      -->
    <xsl:variable name="entitySystemID" as="xs:string"
      select="replace(relpath:newFile($relpathFromShell, $entFilename), '/rng/', '/dtd/')"
    />
    <!-- Special case the topic module, which does not have a topic.ent file like all the rest (it has
         topicDefn.ent, which is included in the topic.mod file. It has to be included *after* 
         all the domain entity integration parameter entities so that those declarations will
         take precedence over those in topicDefn.ent.
      -->
    <xsl:if test="$entityType != 'ent' or ($entityType = 'ent' and not($entityName = 'topic-dec'))">    
      <xsl:text>&#x0a;&lt;!ENTITY % </xsl:text><xsl:value-of select="$entityName" /><xsl:text>&#x0a;</xsl:text> 
      <xsl:value-of select="str:indent(2)"/>
      <xsl:choose>
        <xsl:when test="$usePublicIDsInShellBoolean">
          <xsl:text>PUBLIC "</xsl:text><xsl:value-of select="$publicId" /><xsl:text>"&#x0a;</xsl:text>
          <xsl:value-of select="str:indent(9)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>SYSTEM </xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="concat('&quot;', $entitySystemID, '&quot;')"/><xsl:text>&#x0a;</xsl:text>
      <xsl:text>&gt;</xsl:text><xsl:value-of select="concat('%', $entityName, ';')"/><xsl:text>&#x0a;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="domainExtension">
    <xsl:apply-templates mode="#current" select="node()" />
  </xsl:template>

  <xsl:template match="*" mode="nestingOverride">
    <xsl:apply-templates mode="#current" select="node()" />
  </xsl:template>

  <xsl:template match="rng:zeroOrMore" mode="nestingOverride">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="#current" />
    <xsl:text>)*</xsl:text>
    <xsl:if test="not(position()=last())"><xsl:text>,</xsl:text></xsl:if>
  </xsl:template>

  <xsl:template match="rng:oneOrMore" mode="nestingOverride">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="#current" />
    <xsl:text>)+</xsl:text>
    <xsl:if test="not(position()=last())"><xsl:text>,</xsl:text></xsl:if>
  </xsl:template>

  <xsl:template match="rng:choice" mode="nestingOverride">
    <xsl:for-each select="rng:*">
        <xsl:apply-templates select="." mode="#current" />
        <xsl:if test="not(position()=last())"><xsl:text> |&#x0a;</xsl:text></xsl:if>
    </xsl:for-each>
    <xsl:if test="not(position()=last())"><xsl:text>,</xsl:text></xsl:if>
  </xsl:template>
  
  <xsl:template match="rng:optional" mode="nestingOverride">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="#current" />
    <xsl:text>)?</xsl:text>
    <xsl:if test="not(position()=last())"><xsl:text>,</xsl:text></xsl:if>
  </xsl:template>

  <xsl:template match="rng:define" mode="nestingOverride">
    <xsl:apply-templates mode="#current" />
  </xsl:template>

  <xsl:template match="rng:ref[@name='info-types']" mode="nestingOverride">
    <xsl:variable name="refTarget" select="key('definesByName',@name)" />
    <xsl:if test="$refTarget">
       <xsl:apply-templates select="$refTarget/rng:*" mode="#current" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="rng:ref[ends-with(@name,'.element')]" mode="nestingOverride">
    <xsl:value-of select="substring-before(@name,'.element')" />
  </xsl:template>

  <xsl:template match="rng:ref" mode="dtdExtension domainExtension">
    <xsl:text>%</xsl:text><xsl:value-of select="@name" /><xsl:text>; </xsl:text>
    <xsl:if test="not(position()=last())">
      <xsl:text>|</xsl:text>
    </xsl:if>
    <xsl:text>&#x0a;</xsl:text>
  </xsl:template>

  <xsl:template match="rng:empty" mode="dtdExtension">
    <xsl:comment> empty </xsl:comment>
  </xsl:template>

  <xsl:template match="*" mode="localDefinition">
    <xsl:apply-templates mode="#current" select="node()" />
  </xsl:template>

  <xsl:template match="rng:element" mode="localDefinition">
    <xsl:apply-templates select="../rnga:documentation | rnga:documentation" />
    <!-- Element declaration -->
    <xsl:text>&lt;!ELEMENT  </xsl:text>
    <xsl:value-of select="@name" />
    <xsl:text>    </xsl:text>
    <xsl:variable name="subElements" select="rng:*[not(ends-with(@name, '.attlist'))]"/>
    <xsl:if test="count($subElements) &gt; 1 or local-name($subElements[1])='text'">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="$subElements" mode="moduleFile" />
    <xsl:if test="count($subElements) &gt; 1 or local-name($subElements[1])='text'">
      <xsl:text>)</xsl:text>
    </xsl:if>
    <xsl:text> &gt;&#x0a;</xsl:text>

    <xsl:if test="rng:ref[ends-with(@name, '.attlist')]">
      <xsl:variable name="refPointer" select="rng:ref[ends-with(@name, '.attlist')]" />
      <xsl:variable name="refTarget" select="key('definesByName',$refPointer/@name)" />
      <xsl:choose>
        <xsl:when test="not($refTarget)">
          <xsl:text>&lt;!ATTLIST  </xsl:text>
          <xsl:value-of select="@name" />
          <xsl:text>&#x0a;  </xsl:text>
          <xsl:apply-templates select="$refPointer" mode="moduleFile" />
          <xsl:text>&gt;&#x0a;&#x0a;</xsl:text>
        </xsl:when>
        <xsl:when test="$refTarget/rng:empty">
          <xsl:text>&#x0a;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="$refTarget/rnga:*" mode="moduleFile" />
          <xsl:text>&lt;!ATTLIST  </xsl:text>
          <xsl:value-of select="@name" />
          <xsl:text>&#x0a;  </xsl:text>
          <xsl:apply-templates select="$refTarget/rng:*" mode="moduleFile" />
          <xsl:text>&gt;&#x0a;&#x0a;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="dtdFile">
    <!-- Most stuff we don't care about -->
  </xsl:template>

  <xsl:template match="rnga:documentation" mode="dtdFile" />

  <xsl:template match="comment()" mode="dtdFile">
    <!-- Suppress comments in dtdFile mode -->
  </xsl:template>
  

</xsl:stylesheet>