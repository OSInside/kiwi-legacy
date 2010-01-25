<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:exslt="http://exslt.org/common"
	exclude-result-prefixes="exslt"
>

<xsl:import href="pretty.xsl"/>
<xsl:import href="convert41toXX.xsl"/>

<xsl:output encoding="utf-8"/>

<xsl:template match="/">
	<xsl:variable name="v41">
		<xsl:apply-templates select="/" mode="conv41toXX"/>
	</xsl:variable>

	<xsl:apply-templates
		select="exslt:node-set($v41)" mode="pretty"
	/>
</xsl:template>

</xsl:stylesheet>
