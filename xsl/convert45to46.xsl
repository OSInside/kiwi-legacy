<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml"
	indent="yes" omit-xml-declaration="no" encoding="utf-8"/>
<xsl:strip-space elements="type"/>

<!-- default rule -->
<xsl:template match="*|processing-instruction()|comment()" mode="conv45to46">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates mode="conv45to46"/>
	</xsl:copy>  
</xsl:template>

<!-- update schema version -->
<para xmlns="http://docbook.org/ns/docbook">
	Changed attribute <tag class="attribute">schemaversion</tag>
	to <tag class="attribute">schemaversion</tag> from
	<literal>4.5</literal> to <literal>4.6</literal>.
</para>
<xsl:template match="image" mode="conv44to45">
	<image schemaversion="4.6">
		<xsl:copy-of select="@*[local-name() != 'schemaversion']"/>
		<xsl:apply-templates mode="conv45to46"/>
	</image>
</xsl:template>

<!-- update vmware / vmx -->
<para xmlns="http://docbook.org/ns/docbook"> 
	Change attribute value <tag class="attribute">vmware</tag> to 
	<tag class="attribute">vmx</tag>.
</para>
<xsl:template match="packages[@type='vmware']" mode="conv45to46">
	<packages type="vmx">
		<xsl:apply-templates mode="conv45to46"/>
	</packages>
</xsl:template>

</xsl:stylesheet>
